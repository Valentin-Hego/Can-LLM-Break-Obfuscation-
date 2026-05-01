#!/usr/bin/env bash
set -euo pipefail

# =========================
# Configuration
# =========================

RUN_MOVFUSCATOR="${RUN_MOVFUSCATOR:-0}"
MAX_ASM_LINES="${MAX_ASM_LINES:-800}"
MAX_ASM_BYTES="${MAX_ASM_BYTES:-120000}"

rm -rf outputs
mkdir -p outputs/{baseline,tigress,movfuscator,tmp,asm,prompts}

# Toujours tenter de produire une archive, même si le job échoue.
cleanup_archive() {
  if [ -d outputs ]; then
    tar -czf outputs.tar.gz outputs/ || true
  fi
}
trap cleanup_archive EXIT

# =========================
# Fonctions utilitaires
# =========================

detect_target_func() {
  local src="$1"

  # Détection simple de la première fonction C non-main.
  # Suffisant pour tes samples si chaque fichier contient une fonction principale à tester.
  grep -E '^[[:space:]]*(int|long|short|char|void|float|double|unsigned|signed)[[:space:]\*]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(' "$src" \
    | grep -vE '\bmain[[:space:]]*\(' \
    | head -n 1 \
    | sed -E 's/^[[:space:]]*(int|long|short|char|void|float|double|unsigned|signed)[[:space:]\*]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(.*/\2/' \
    || true
}

detect_signature() {
  local src="$1"
  local func="$2"

  # Essaie de récupérer la ligne de signature.
  # Exemple : int add(int x, int y) {
  local sig
  sig="$(grep -E "^[[:space:]]*(int|long|short|char|void|float|double|unsigned|signed)[[:space:]\*]+${func}[[:space:]]*\(" "$src" \
    | head -n 1 \
    | sed -E 's/[[:space:]]*\{[[:space:]]*$//' \
    | sed -E 's/[[:space:]]*$//' \
    || true)"

  if [ -z "$sig" ]; then
    echo "${func}(/* signature inconnue */)"
  else
    echo "$sig"
  fi
}

dump_limited_asm() {
  local bin="$1"
  local asm_file="$2"
  local max_lines="${3:-800}"

  # Avec pipefail activé, objdump peut échouer à cause du SIGPIPE quand head s'arrête.
  # On désactive donc pipefail uniquement pour ce pipeline.
  set +o pipefail
  objdump -d -Mintel "$bin" | head -n "$max_lines" > "$asm_file"
  set -o pipefail
}

truncate_asm_if_needed() {
  local asm_file="$1"
  local max_bytes="${2:-120000}"

  if [ ! -f "$asm_file" ]; then
    return 0
  fi

  local size
  size="$(wc -c < "$asm_file")"

  if [ "$size" -gt "$max_bytes" ]; then
    echo "    [!] ASM trop gros (${size} bytes), troncature à ${max_bytes} bytes"
    head -c "$max_bytes" "$asm_file" > "${asm_file}.truncated"
    mv "${asm_file}.truncated" "$asm_file"
  fi
}

generate_asm_and_prompt() {
  local src="$1"
  local backend="$2"
  local transform="$3"
  local category="$4"
  local bin="$5"
  local target_func="$6"
  local target_signature="$7"

  local base
  base="$(basename "$src" .c)"

  local asm_dir="outputs/asm/${backend}/${transform}/${category}"
  local prompt_dir="outputs/prompts/${backend}/${transform}/${category}"

  mkdir -p "$asm_dir" "$prompt_dir"

  local asm_file="${asm_dir}/${base}.asm"
  local prompt_file="${prompt_dir}/${base}_prompt.txt"

  echo "    [+] Extraction ASM : ${backend}/${transform}/${category}/${base}"
  echo "    [+] Fonction cible : ${target_func}"

  # Extraction ciblée de la fonction.
  if objdump -d -Mintel --disassemble="$target_func" "$bin" > "$asm_file" 2>/dev/null; then
    if grep -q "<${target_func}>" "$asm_file"; then
      echo "    [+] Fonction ${target_func} trouvée"
    else
      echo "    [!] Fonction ${target_func} introuvable"

      if [ "$backend" = "movfuscator" ]; then
        echo "    [!] Movfuscator : pas de fallback complet, prompt ignoré"
        rm -f "$asm_file"
        return 0
      fi

      echo "    [!] Fallback limité à ${MAX_ASM_LINES} lignes"
      dump_limited_asm "$bin" "$asm_file" "$MAX_ASM_LINES"
    fi
  else
    echo "    [!] Extraction ciblée impossible"

    if [ "$backend" = "movfuscator" ]; then
      echo "    [!] Movfuscator : pas de fallback complet, prompt ignoré"
      rm -f "$asm_file"
      return 0
    fi

    echo "    [!] Fallback limité à ${MAX_ASM_LINES} lignes"
    dump_limited_asm "$bin" "$asm_file" "$MAX_ASM_LINES"
  fi

  truncate_asm_if_needed "$asm_file" "$MAX_ASM_BYTES"

  if [ ! -s "$asm_file" ]; then
    echo "    [!] ASM vide, prompt non généré"
    return 0
  fi

  echo "    [+] Génération prompt : $prompt_file"

  {
    echo "Tu es un expert en reverse engineering de binaires Linux x86-64."
    echo
    echo "À partir du code assembleur Intel ci-dessous, reconstruis le code C correspondant."
    echo
    echo "Contraintes obligatoires :"
    echo "- Réponds uniquement avec du code C."
    echo "- Ne donne aucune explication."
    echo "- Ne mets pas de Markdown."
    echo "- Ne mets pas de main."
    echo "- Le code doit être compilable avec gcc."
    echo "- La fonction reconstruite doit avoir exactement cette signature :"
    echo "${target_signature};"
    echo "- Le nom de la fonction doit être ${target_func}."
    echo "- Préserve strictement la sémantique : conditions, boucles, calculs, valeurs de retour."
    echo "- Si le code assembleur contient de l'obfuscation, simplifie-la uniquement si le comportement reste identique."
    echo "- Utilise des noms de variables simples : x, y, a, b, i, j, tmp."
    echo
    echo "Assembleur :"
    echo '```asm'
    cat "$asm_file"
    echo '```'
  } > "$prompt_file"
}

# =========================
# Baseline
# =========================

echo "[+] Baseline"

for src in samples/*.c; do
  [ -e "$src" ] || { echo "No .c files in samples/"; exit 1; }

  base="$(basename "$src" .c)"
  gcc -O0 -g "$src" -o "outputs/baseline/${base}"
done

# =========================
# Tigress
# =========================

echo "[+] Tigress (v4) - Test des Transforms un à un par catégorie"

TRANSFORMS=("Flatten" "EncodeLiterals" "EncodeArithmetic" "Split" "Virtualize")
CATEGORIES=("arithmetic" "function_call" "loops")

for transform in "${TRANSFORMS[@]}"; do
  echo "  -> Application du Transform : $transform"

  for category in "${CATEGORIES[@]}"; do
    outdir="outputs/tigress/${transform}/${category}"
    mkdir -p "$outdir"

    for src in samples/${category}_*.c; do
      [ -e "$src" ] || continue

      base="$(basename "$src" .c)"

      target_func="$(detect_target_func "$src")"

      if [ -z "$target_func" ]; then
        echo "    [!] Fonction cible non détectée dans $src, utilisation de main"
        target_func="main"
      fi

      target_signature="$(detect_signature "$src" "$target_func")"

      echo "    [+] Sample : $base"
      echo "    [+] Fonction détectée : $target_func"
      echo "    [+] Signature détectée : $target_signature"

      wrap="outputs/tmp/${base}_${transform}_wrap.c"
      obfc="${outdir}/${base}_obf.c"
      outbin="${outdir}/${base}_obf"

      # Wrapper sans toucher au fichier original.
      {
        echo "/* Auto-generated wrapper for Tigress */"
        echo "#include <stdio.h>"
        echo "#include <stdlib.h>"
        echo "#include <stdint.h>"
        echo "#include <string.h>"
        echo "#include <time.h>"
        echo "#include <pthread.h>"
        echo "#include <unistd.h>"
        echo
        cat "$src"
      } > "$wrap"

      # Base commune à toutes les exécutions.
      TIGRESS_OPTS="--Environment=x86_64:Linux:Gcc --Seed=0"
      TIGRESS_OPTS="$TIGRESS_OPTS --Transform=InitEntropy"
      TIGRESS_OPTS="$TIGRESS_OPTS --Transform=InitOpaque --Functions=main --InitOpaqueStructs=list,array --InitOpaqueCount=2 --InitOpaqueSize=30"

      # Options spécifiques selon le transform.
      # On obfusque uniquement la fonction détectée, pas tout le programme.
      case "$transform" in
        Flatten)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=Flatten --Functions=${target_func} --FlattenDispatch=switch,goto,indirect --FlattenObfuscateNext=true --FlattenOpaqueStructs=array"
          ;;
        EncodeLiterals)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=EncodeLiterals --Functions=${target_func} --EncodeLiteralsIntegerKinds=split,opaque"
          ;;
        EncodeArithmetic)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=EncodeArithmetic --Functions=${target_func}"
          ;;
        Split)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=Split --Functions=${target_func}"
          ;;
        Virtualize)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=Virtualize --Functions=${target_func}"
          ;;
        *)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=$transform --Functions=${target_func}"
          ;;
      esac

      docker run --rm -v "$PWD:/work" -w /work psec/tigress:4 \
        bash -lc "tigress $TIGRESS_OPTS --out=${obfc} ${wrap} && gcc -O0 -g ${obfc} -o ${outbin}"

      generate_asm_and_prompt "$src" "tigress" "$transform" "$category" "$outbin" "$target_func" "$target_signature"
    done
  done
done

# =========================
# Movfuscator, désactivé par défaut
# =========================

if [ "$RUN_MOVFUSCATOR" = "1" ]; then
  echo "[+] Movfuscator"

  SOFTFLOAT="/opt/movfuscator/movfuscator/lib/softfloatfull.o"

  for src in samples/*.c; do
    [ -e "$src" ] || { echo "No .c files in samples/"; break; }

    base="$(basename "$src" .c)"
    category="${base%%_*}"

    target_func="$(detect_target_func "$src")"

    if [ -z "$target_func" ]; then
      echo "    [!] Fonction cible non détectée dans $src, utilisation de main"
      target_func="main"
    fi

    target_signature="$(detect_signature "$src" "$target_func")"

    outbin="outputs/movfuscator/${base}_mov"

    docker run --rm \
      -v "$PWD:/work" -w /work \
      psec/movfuscator:1 \
      bash -lc "/opt/movfuscator/build/movcc '$src' -o '$outbin' -Wl'$SOFTFLOAT'"

    generate_asm_and_prompt "$src" "movfuscator" "movfuscator" "$category" "$outbin" "$target_func" "$target_signature"
  done
else
  echo "[+] Movfuscator désactivé par défaut"
  echo "    Pour l'activer : RUN_MOVFUSCATOR=1 ./scripts/run_all.sh"
fi

# =========================
# Nettoyage et compression
# =========================

echo "[+] Nettoyage des fichiers intermédiaires"
rm -rf outputs/tmp
rm -f outputs/movfuscator/*.o outputs/movfuscator/*.s

echo "[+] Compression des artefacts"
tar -czf outputs.tar.gz outputs/

echo "[+] Done"
echo "[+] Prompts générés dans : outputs/prompts/"
echo "[+] ASM générés dans : outputs/asm/"
echo "[+] Archive : outputs.tar.gz"
#!/usr/bin/env bash
set -euo pipefail

# =========================
# Configuration
# =========================

ASM_SYNTAX="${ASM_SYNTAX:-att}"          # att ou intel
RUN_MOVFUSCATOR="${RUN_MOVFUSCATOR:-0}" # 0 par défaut
MAX_ASM_LINES="${MAX_ASM_LINES:-800}"   # utilisé seulement pour le prompt en fallback
MAX_ASM_BYTES="${MAX_ASM_BYTES:-120000}" # utilisé seulement pour le prompt

rm -rf outputs
mkdir -p outputs/{baseline,tigress,movfuscator,tmp,asm,prompts}

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

  grep -E '^[[:space:]]*(int|long|short|char|void|float|double|unsigned|signed)[[:space:]\*]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(' "$src" \
    | grep -vE '\bmain[[:space:]]*\(' \
    | head -n 1 \
    | sed -E 's/^[[:space:]]*(int|long|short|char|void|float|double|unsigned|signed)[[:space:]\*]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(.*/\2/' \
    || true
}

detect_signature() {
  local src="$1"
  local func="$2"

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

objdump_full() {
  local bin="$1"
  local out="$2"

  if [ "$ASM_SYNTAX" = "intel" ]; then
    objdump -d -Mintel "$bin" > "$out"
  else
    objdump -d "$bin" > "$out"
  fi
}

objdump_function() {
  local bin="$1"
  local func="$2"
  local out="$3"

  if [ "$ASM_SYNTAX" = "intel" ]; then
    objdump -d -Mintel --disassemble="$func" "$bin" > "$out" 2>/dev/null || true
  else
    objdump -d --disassemble="$func" "$bin" > "$out" 2>/dev/null || true
  fi
}

objdump_limited_for_prompt() {
  local bin="$1"
  local out="$2"

  set +o pipefail
  if [ "$ASM_SYNTAX" = "intel" ]; then
    objdump -d -Mintel "$bin" | head -n "$MAX_ASM_LINES" > "$out"
  else
    objdump -d "$bin" | head -n "$MAX_ASM_LINES" > "$out"
  fi
  set -o pipefail
}

truncate_prompt_asm_if_needed() {
  local file="$1"

  if [ ! -f "$file" ]; then
    return 0
  fi

  local size
  size="$(wc -c < "$file")"

  if [ "$size" -gt "$MAX_ASM_BYTES" ]; then
    echo "    [!] ASM du prompt trop gros (${size} bytes), troncature à ${MAX_ASM_BYTES} bytes"
    head -c "$MAX_ASM_BYTES" "$file" > "${file}.truncated"
    mv "${file}.truncated" "$file"
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
  local prompt_func_asm="outputs/tmp/${base}_${backend}_${transform}_${category}_prompt_func.asm"

  echo "    [+] Extraction ASM complet : ${backend}/${transform}/${category}/${base}"
  echo "    [+] Syntaxe ASM : ${ASM_SYNTAX}"
  echo "    [+] Fonction cible pour prompt : ${target_func}"

  # Le fichier outputs/asm est TOUJOURS le désassemblage complet du binaire.
  objdump_full "$bin" "$asm_file"

  # Pour le prompt uniquement, on tente d'extraire la fonction cible.
  objdump_function "$bin" "$target_func" "$prompt_func_asm"

  if ! grep -q "<${target_func}>" "$prompt_func_asm" 2>/dev/null; then
    echo "    [!] Fonction ${target_func} introuvable pour le prompt"
    echo "    [!] Fallback prompt limité à ${MAX_ASM_LINES} lignes du binaire complet"
    objdump_limited_for_prompt "$bin" "$prompt_func_asm"
  fi

  truncate_prompt_asm_if_needed "$prompt_func_asm"

  if [ ! -s "$prompt_func_asm" ]; then
    echo "    [!] ASM du prompt vide, prompt non généré"
    return 0
  fi

  echo "    [+] Génération prompt : $prompt_file"

  {
    echo "Tu es un expert en reverse engineering de binaires Linux x86-64."
    echo
    echo "À partir du code assembleur ci-dessous, reconstruis le code C correspondant."
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
    echo "Informations :"
    echo "- Backend : ${backend}"
    echo "- Transform : ${transform}"
    echo "- Catégorie : ${category}"
    echo "- Sample : ${base}"
    echo "- Syntaxe assembleur : ${ASM_SYNTAX}"
    echo
    echo "Assembleur de la fonction cible ou extrait limité :"
    echo '```asm'
    cat "$prompt_func_asm"
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

      TIGRESS_OPTS="--Environment=x86_64:Linux:Gcc --Seed=0"
      TIGRESS_OPTS="$TIGRESS_OPTS --Transform=InitEntropy"
      TIGRESS_OPTS="$TIGRESS_OPTS --Transform=InitOpaque --Functions=main --InitOpaqueStructs=list,array --InitOpaqueCount=2 --InitOpaqueSize=30"

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
# Movfuscator
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
echo "[+] ASM complets générés dans : outputs/asm/"
echo "[+] Prompts générés dans : outputs/prompts/"
echo "[+] Archive : outputs.tar.gz"
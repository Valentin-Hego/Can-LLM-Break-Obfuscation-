#!/usr/bin/env bash
set -euo pipefail

# =========================
# Configuration
# =========================

ASM_SYNTAX="${ASM_SYNTAX:-att}"           # att ou intel
RUN_MOVFUSCATOR="${RUN_MOVFUSCATOR:-0}"  # 0 par défaut
MAX_ASM_LINES="${MAX_ASM_LINES:-1200}"   # fallback prompt
MAX_ASM_BYTES="${MAX_ASM_BYTES:-180000}" # taille max ASM dans prompt

rm -rf outputs
mkdir -p outputs/{baseline,tigress_hard,movfuscator,tmp,asm,prompts,logs}

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

detect_category() {
  local src="$1"
  local base
  base="$(basename "$src" .c)"

  if [[ "$base" == *_* ]]; then
    echo "${base%%_*}"
  else
    echo "generic"
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

  objdump_full "$bin" "$asm_file"
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
    echo "- Ne donne que la fonction reconstruite."
    echo "- Le nom de la fonction doit être ${target_func}."
    echo "- Déduis toi-même le nombre et le type des paramètres à partir de l'assembleur."
    echo "- Ne te base pas sur une signature source fournie : elle n'est volontairement pas donnée."
    echo "- Préserve strictement la sémantique : conditions, boucles, calculs, valeurs de retour."
    echo "- Si le code assembleur contient de l'obfuscation, simplifie-la uniquement si le comportement reste identique."
    echo "- Utilise des noms de variables simples : x, y, a, b, i, j, tmp."
    echo
    echo
    echo "Assembleur du binaire cible:"
    echo '```asm'
    cat "$prompt_func_asm"
    echo '```'
  } > "$prompt_file"
}

build_tigress_options_for_transform() {
  local transform="$1"
  local target_func="$2"

  case "$transform" in
    Flatten)
      echo "--Transform=Flatten --Functions=${target_func} --FlattenDispatch=switch,goto,indirect --FlattenObfuscateNext=true --FlattenOpaqueStructs=array"
      ;;
    EncodeLiterals)
      echo "--Transform=EncodeLiterals --Functions=${target_func} --EncodeLiteralsIntegerKinds=split,opaque"
      ;;
    EncodeArithmetic)
      echo "--Transform=EncodeArithmetic --Functions=${target_func}"
      ;;
    Split)
      echo "--Transform=Split --Functions=${target_func}"
      ;;
    Virtualize)
      echo "--Transform=Virtualize --Functions=${target_func}"
      ;;
    *)
      echo "--Transform=${transform} --Functions=${target_func}"
      ;;
  esac
}

make_tigress_wrapper() {
  local src="$1"
  local wrap="$2"
  local label="$3"

  {
    echo "/* Auto-generated wrapper for Tigress ${label} */"
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
}

run_tigress_build() {
  local opts="$1"
  local obfc="$2"
  local wrap="$3"
  local outbin="$4"
  local logfile="$5"

  docker run --rm -v "$PWD:/work" -w /work psec/tigress:4 \
    bash -lc "tigress $opts --out=${obfc} ${wrap} && gcc -O0 -g ${obfc} -o ${outbin}" \
    > "$logfile" 2>&1
}

# =========================
# Baseline
# =========================

echo "[+] Baseline"

for src in samples/*.c; do
  [ -e "$src" ] || { echo "No .c files in samples/"; exit 1; }

  base="$(basename "$src" .c)"

  echo "  [+] Compilation baseline : $base"

  if gcc -O0 -g "$src" -o "outputs/baseline/${base}"; then
    :
  else
    echo "  [!] Échec compilation baseline : $base"
    continue
  fi
done

# =========================
# Tigress - Obfuscations dures
# =========================

echo "[+] Tigress (v4) - Obfuscations agressives"

# Format :
# nom_combo|suite_de_transforms
#
# Principe :
# - Split avant Virtualize est plus stable que Virtualize puis Split.
# - Virtualize est volontairement placé en fin sur les combos les plus durs.
# - Certains combos peuvent échouer selon le code source : le script continue.
TIGRESS_HARD_COMBOS=(
  "hard_flatten_literals_arith|Flatten EncodeLiterals EncodeArithmetic"
  "hard_split_flatten_literals_arith|Split Flatten EncodeLiterals EncodeArithmetic"
  "hard_split_arith_literals_flatten|Split EncodeArithmetic EncodeLiterals Flatten"
  "hard_flatten_split_arith_literals|Flatten Split EncodeArithmetic EncodeLiterals"
  "hard_split_flatten_virtualize|Split Flatten Virtualize"
  "hard_split_arith_literals_virtualize|Split EncodeArithmetic EncodeLiterals Virtualize"
  "hard_flatten_arith_literals_virtualize|Flatten EncodeArithmetic EncodeLiterals Virtualize"
  "max_split_flatten_arith_literals_virtualize|Split Flatten EncodeArithmetic EncodeLiterals Virtualize"
)

for combo_entry in "${TIGRESS_HARD_COMBOS[@]}"; do
  combo_name="${combo_entry%%|*}"
  combo_transforms="${combo_entry#*|}"

  echo "  -> Application du combo dur : $combo_name"
  echo "     Transforms : $combo_transforms"

  for src in samples/*.c; do
    [ -e "$src" ] || continue

    base="$(basename "$src" .c)"
    category="$(detect_category "$src")"
    target_func="$(detect_target_func "$src")"

    if [ -z "$target_func" ]; then
      echo "    [!] Fonction cible non détectée dans $src, utilisation de main"
      target_func="main"
    fi

    echo "    [+] Sample : $base"
    echo "    [+] Catégorie : $category"
    echo "    [+] Fonction détectée : $target_func"

    outdir="outputs/tigress_hard/${combo_name}/${category}"
    mkdir -p "$outdir"

    wrap="outputs/tmp/${base}_${combo_name}_wrap.c"
    obfc="${outdir}/${base}_obf.c"
    outbin="${outdir}/${base}_obf"
    logfile="outputs/logs/${base}_${combo_name}.log"

    make_tigress_wrapper "$src" "$wrap" "$combo_name"

    TIGRESS_OPTS="--Environment=x86_64:Linux:Gcc --Seed=0"

    # Initialisation commune pour opaque predicates / entropie.
    TIGRESS_OPTS="$TIGRESS_OPTS --Transform=InitEntropy"
    TIGRESS_OPTS="$TIGRESS_OPTS --Transform=InitOpaque --Functions=main --InitOpaqueStructs=list,array --InitOpaqueCount=4 --InitOpaqueSize=60"

    # Chaîne d'obfuscation dure.
    for transform in $combo_transforms; do
      TIGRESS_OPTS="$TIGRESS_OPTS $(build_tigress_options_for_transform "$transform" "$target_func")"
    done

    if run_tigress_build "$TIGRESS_OPTS" "$obfc" "$wrap" "$outbin" "$logfile"; then
      echo "    [+] Build Tigress OK : $combo_name / $base"
      generate_asm_and_prompt "$src" "tigress_hard" "$combo_name" "$category" "$outbin" "$target_func"
    else
      echo "    [!] Échec Tigress combo=${combo_name} sample=${base}, passage au suivant"
      echo "    [!] Log : $logfile"
      continue
    fi
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
    category="$(detect_category "$src")"
    target_func="$(detect_target_func "$src")"

    if [ -z "$target_func" ]; then
      echo "    [!] Fonction cible non détectée dans $src, utilisation de main"
      target_func="main"
    fi

    echo "    [+] Sample : $base"
    echo "    [+] Catégorie : $category"
    echo "    [+] Fonction détectée : $target_func"

    outbin="outputs/movfuscator/${base}_mov"
    logfile="outputs/logs/${base}_movfuscator.log"

    if docker run --rm \
      -v "$PWD:/work" -w /work \
      psec/movfuscator:1 \
      bash -lc "/opt/movfuscator/build/movcc '$src' -o '$outbin' -Wl'$SOFTFLOAT'" \
      > "$logfile" 2>&1; then

      generate_asm_and_prompt "$src" "movfuscator" "movfuscator" "$category" "$outbin" "$target_func"

    else
      echo "    [!] Échec Movfuscator sample=${base}, passage au suivant"
      echo "    [!] Log : $logfile"
      continue
    fi
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
echo "[+] Binaires baseline : outputs/baseline/"
echo "[+] Binaires Tigress hard : outputs/tigress_hard/"
echo "[+] ASM complets générés dans : outputs/asm/"
echo "[+] Prompts générés dans : outputs/prompts/"
echo "[+] Logs générés dans : outputs/logs/"
echo "[+] Archive : outputs.tar.gz"
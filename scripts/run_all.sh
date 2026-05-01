#!/usr/bin/env bash
set -euo pipefail

TARGET_FUNC="${TARGET_FUNC:-target}"
TARGET_SIGNATURE="${TARGET_SIGNATURE:-int target(int x, int y)}"

rm -rf outputs
mkdir -p outputs/{baseline,tigress,movfuscator,tmp,asm,prompts}

generate_asm_and_prompt() {
  local src="$1"
  local backend="$2"
  local transform="$3"
  local category="$4"
  local bin="$5"

  local base
  base="$(basename "$src" .c)"

  local asm_dir="outputs/asm/${backend}/${transform}/${category}"
  local prompt_dir="outputs/prompts/${backend}/${transform}/${category}"

  mkdir -p "$asm_dir" "$prompt_dir"

  local asm_file="${asm_dir}/${base}.asm"
  local prompt_file="${prompt_dir}/${base}_prompt.txt"

  local max_lines="${MAX_ASM_LINES:-800}"

  echo "    [+] Extraction ASM : ${backend}/${transform}/${category}/${base}"

  # Tentative d'extraction ciblée de la fonction.
  if objdump -d -Mintel --disassemble="$TARGET_FUNC" "$bin" > "$asm_file" 2>/dev/null; then
    if grep -q "<${TARGET_FUNC}>" "$asm_file"; then
      echo "    [+] Fonction ${TARGET_FUNC} trouvée"
    else
      echo "    [!] Fonction ${TARGET_FUNC} introuvable"

      if [ "$backend" = "movfuscator" ]; then
        echo "    [!] Movfuscator : pas de fallback complet, fichier ignoré"
        rm -f "$asm_file"
        return 0
      fi

      echo "    [!] Fallback limité à ${max_lines} lignes"
      objdump -d -Mintel "$bin" | head -n "$max_lines" > "$asm_file"
    fi
  else
    echo "    [!] Extraction ciblée impossible"

    if [ "$backend" = "movfuscator" ]; then
      echo "    [!] Movfuscator : pas de fallback complet, fichier ignoré"
      rm -f "$asm_file"
      return 0
    fi

    echo "    [!] Fallback limité à ${max_lines} lignes"
    objdump -d -Mintel "$bin" | head -n "$max_lines" > "$asm_file"
  fi

  # Sécurité : si le fichier ASM est trop gros, on le tronque.
  local max_bytes="${MAX_ASM_BYTES:-120000}"

  if [ -f "$asm_file" ]; then
    local size
    size="$(wc -c < "$asm_file")"

    if [ "$size" -gt "$max_bytes" ]; then
      echo "    [!] ASM trop gros (${size} bytes), troncature à ${max_bytes} bytes"
      head -c "$max_bytes" "$asm_file" > "${asm_file}.truncated"
      mv "${asm_file}.truncated" "$asm_file"
    fi
  else
    echo "    [!] Pas de fichier ASM généré"
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
    echo "${TARGET_SIGNATURE};"
    echo "- Le nom de la fonction doit être ${TARGET_FUNC}."
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


echo "[+] Baseline"
for src in samples/*.c; do
  [ -e "$src" ] || { echo "No .c files in samples/"; exit 1; }

  base="$(basename "$src" .c)"
  gcc -O0 -g "$src" -o "outputs/baseline/${base}"
done

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
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=Flatten --Functions=* --FlattenDispatch=switch,goto,indirect --FlattenObfuscateNext=true --FlattenOpaqueStructs=array"
          ;;
        EncodeLiterals)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=EncodeLiterals --Functions=* --EncodeLiteralsIntegerKinds=split,opaque"
          ;;
        EncodeArithmetic)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=EncodeArithmetic --Functions=*"
          ;;
        *)
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=$transform --Functions=*"
          ;;
      esac

      docker run --rm -v "$PWD:/work" -w /work psec/tigress:4 \
        bash -lc "tigress $TIGRESS_OPTS --out=${obfc} ${wrap} && gcc -O0 -g ${obfc} -o ${outbin}"

      generate_asm_and_prompt "$src" "tigress" "$transform" "$category" "$outbin"
    done
  done
done

echo "[+] Movfuscator"
SOFTFLOAT="/opt/movfuscator/movfuscator/lib/softfloatfull.o"

for src in samples/*.c; do
  [ -e "$src" ] || { echo "No .c files in samples/"; break; }

  base="$(basename "$src" .c)"

  # Catégorie déduite du préfixe du fichier : arithmetic_001 -> arithmetic
  category="${base%%_*}"

  outbin="outputs/movfuscator/${base}_mov"

  docker run --rm \
    -v "$PWD:/work" -w /work \
    psec/movfuscator:1 \
    bash -lc "/opt/movfuscator/build/movcc '$src' -o '$outbin' -Wl'$SOFTFLOAT'"

  generate_asm_and_prompt "$src" "movfuscator" "movfuscator" "$category" "$outbin"
done

echo "[+] Nettoyage des fichiers intermédiaires"
rm -rf outputs/tmp

rm -f outputs/movfuscator/*.o outputs/movfuscator/*.s

echo "[+] Compression des artefacts"
tar -czf outputs.tar.gz outputs/

echo "[+] Done"
echo "[+] Prompts générés dans : outputs/prompts/"
echo "[+] ASM générés dans : outputs/asm/"
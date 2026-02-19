#!/usr/bin/env bash
set -euo pipefail

SAMPLES_DIR="samples"
OUT_DIR="outputs"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"/{baseline,tigress,movfuscator}

shopt -s nullglob
files=("$SAMPLES_DIR"/*.c)
if (( ${#files[@]} == 0 )); then
  echo "No .c files found in $SAMPLES_DIR/"
  exit 1
fi

echo "[+] Baseline"
for f in "${files[@]}"; do
  base="$(basename "$f" .c)"
  gcc -O0 -g "$f" -o "$OUT_DIR/baseline/$base"
done

echo "[+] Tigress (v4)"
for f in "${files[@]}"; do
  base="$(basename "$f" .c)"
  docker run --rm \
    -v "$PWD:/work" -w /work \
    psec/tigress:4 \
    bash -lc "
      set -e
      tigress \
        --Environment=x86_64:Linux:Gcc \
        --Transform=InitOpaque --Functions=main \
        --Transform=EncodeLiterals --Functions=main \
        --out=$OUT_DIR/tigress/${base}_obf.c \
        $f
      gcc -O0 -g $OUT_DIR/tigress/${base}_obf.c -o $OUT_DIR/tigress/${base}_obf
    "
done

echo "[+] Movfuscator"
for f in "${files[@]}"; do
  base="$(basename "$f" .c)"
  docker run --rm \
    -v "$PWD:/work" -w /work \
    psec/movfuscator:1 \
    movcc "$f" -o "$OUT_DIR/movfuscator/${base}_mov"
done

echo "[+] Remove .c files from samples/"
rm -f "$SAMPLES_DIR"/*.c

echo "[+] Success"

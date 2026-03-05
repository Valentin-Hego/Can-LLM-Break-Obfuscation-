#!/usr/bin/env bash
set -euo pipefail

rm -rf outputs
mkdir -p outputs/{baseline,tigress,movfuscator,tmp}

echo "[+] Baseline"
for src in samples/*.c; do
  base="$(basename "$src" .c)"
  gcc -O0 -g "$src" -o "outputs/baseline/${base}"
done

echo "[+] Tigress (v4) - wrapper includes + obfuscation"
for src in samples/*.c; do
  base="$(basename "$src" .c)"
  wrap="outputs/tmp/${base}_wrap.c"
  obfc="outputs/tigress/${base}_obf.c"
  outbin="outputs/tigress/${base}_obf"

  # Wrapper sans toucher au fichier original
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

  docker run --rm \
    -v "$PWD:/work" -w /work \
    psec/tigress:4 \
    bash -lc "
      tigress \
        --Environment=x86_64:Linux:Gcc \
        --Transform=InitOpaque --Functions=main \
        --Transform=EncodeLiterals --Functions=main \
        --out='$obfc' \
        '$wrap'
      && gcc -O0 -g '$obfc' -o '$outbin'
    "
done

echo "[+] Movfuscator"
for src in samples/*.c; do
  base="$(basename "$src" .c)"
  docker run --rm \
    -v "$PWD:/work" -w /work \
    psec/movfuscator:1 \
    /opt/movfuscator/build/movcc "$src" -o "outputs/movfuscator/${base}_mov"
done

echo "[+] Cleanup samples"
rm -f samples/*.c

echo "[+] Done"
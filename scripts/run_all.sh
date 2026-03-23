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
    bash -lc "set -e
      tigress \
        --Environment=x86_64:Linux:Gcc \
        --Seed=0 \
        \
        --Transform=InitOpaque \
          --Functions=main \
          --InitOpaqueStructs=list,array \
          --InitOpaqueCount=2 \
          --InitOpaqueSize=30 \
        \
        --Transform=EncodeLiterals \
          --Functions=* \
          --EncodeLiteralsIntegerKinds=split,opaque \
        \
        --Transform=EncodeArithmetic \
          --Functions=* \
        \
        --Transform=AddOpaque \
          --Functions=* \
          --AddOpaqueCount=2 \
        \
        --Transform=Flatten \
          --Functions=* \
          --FlattenDispatch=switch,goto,indirect \
          --FlattenObfuscateNext=true \
          --FlattenOpaqueStructs=array \
        \
        --out=outputs/tigress/${base}_obf.c \
        outputs/tmp/${base}_wrap.c

      gcc -O0 -g outputs/tigress/${base}_obf.c -o outputs/tigress/${base}_obf
    "
done

echo "[+] Movfuscator"
SOFTFLOAT="/opt/movfuscator/movfuscator/lib/softfloatfull.o"

for src in samples/*.c; do
  [ -e "$src" ] || { echo "No .c files in samples/"; break; }
  base="$(basename "$src" .c)"

  docker run --rm \
    -v "$PWD:/work" -w /work \
    psec/movfuscator:1 \
    bash -lc "/opt/movfuscator/build/movcc '$src' -o 'outputs/movfuscator/${base}_mov' -Wl'$SOFTFLOAT'"
done

echo "[+] Cleanup samples"
rm -f samples/*.c

echo "[+] Done"
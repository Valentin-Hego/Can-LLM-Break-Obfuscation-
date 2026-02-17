#!/usr/bin/env bash
set -euo pipefail

rm -rf outputs
mkdir -p outputs/baseline
mkdir -p outputs/tigress
mkdir -p outputs/movfuscator

echo "[+] Baseline"
gcc -O0 -g samples/hello.c -o outputs/baseline/hello

echo "[+] Tigress"

TMPFILE=outputs/hello_for_tigress.c
echo '#define _POSIX_C_SOURCE 199309L' > $TMPFILE
echo '#include <time.h>' >> $TMPFILE
cat samples/hello.c >> $TMPFILE

docker run --rm \
  -v "$PWD:/work" -w /work \
  psec/tigress:3.3.3 \
  tigress --Environment=x86_64:Linux:Gcc:4.6 \
        --Transform=InitOpaque \
            --InitOpaqueStructs=list,array,env,input \
            --Functions=main \
        --Transform=InitEntropy \
        --Transform=EncodeLiterals \
            --Functions=main \
        --out=outputs/tigress/hello_obf.c \
        $TMPFILE

docker run --rm \
  -v "$PWD:/work" -w /work \
  psec/tigress:3.3.3 \
  gcc -std=c99 -D_POSIX_C_SOURCE=199309L -O0 -g \
      outputs/tigress/hello_obf.c \
      -o outputs/tigress/hello_obf

echo "[+] Movfuscator"
docker run --rm \
  -v "$PWD:/work" -w /work \
  psec/movfuscator:1 \
  movcc samples/hello.c -o outputs/movfuscator/hello_mov

echo "[+] Done"

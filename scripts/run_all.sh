#!/usr/bin/env bash
set -euo pipefail

rm -rf outputs
mkdir -p outputs/baseline
mkdir -p outputs/tigress
mkdir -p outputs/movfuscator

echo "[+] Baseline"
gcc -O0 -g samples/hello.c -o outputs/baseline/hello

echo "[+] Tigress"
docker run --rm \
  -v "$PWD:/work" -w /work \
  psec/tigress:3.3.3 \
  tigress --Environment=x86_64:Linux:Gcc:4.6 \
          --Transform=EncodeLiterals \
          --Functions=main \
          --out=outputs/tigress/hello_obf.c \
          samples/hello.c

docker run --rm \
  -v "$PWD:/work" -w /work \
  psec/tigress:3.3.3 \
  gcc -O0 -g outputs/tigress/hello_obf.c -o outputs/tigress/hello_obf

echo "[+] Movfuscator"
docker run --rm \
  -v "$PWD:/work" -w /work \
  psec/movfuscator:1 \
  movcc samples/hello.c -o outputs/movfuscator/hello_mov

echo "[+] Done"

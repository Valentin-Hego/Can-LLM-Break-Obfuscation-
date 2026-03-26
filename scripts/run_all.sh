#!/usr/bin/env bash
set -euo pipefail

rm -rf outputs
mkdir -p outputs/{baseline,tigress,movfuscator,tmp}

echo "[+] Baseline"
for src in samples/*.c; do
  base="$(basename "$src" .c)"
  gcc -O0 -g "$src" -o "outputs/baseline/${base}"
done

echo "[+] Tigress (v4) - Test des Transforms un à un par catégorie"

# 1. Liste des transformations à tester individuellement
TRANSFORMS=("Flatten" "EncodeLiterals" "EncodeArithmetic" "Split" "Virtualize")

# 2. Liste des préfixes pour séparer tes fichiers
CATEGORIES=("arithmetic" "function_call" "loops")

for transform in "${TRANSFORMS[@]}"; do
  echo "  -> Application du Transform : $transform"
  
  for category in "${CATEGORIES[@]}"; do
    # Création de l'arborescence : outputs/tigress/<Transform>/<Categorie>/
    outdir="outputs/tigress/${transform}/${category}"
    mkdir -p "$outdir"

    # On boucle uniquement sur les fichiers correspondant à la catégorie en cours
    for src in samples/${category}_*.c; do
      # Sécurité : on passe au suivant si aucun fichier ne correspond
      [ -e "$src" ] || continue 
      
      base="$(basename "$src" .c)"
      # On suffixe le wrapper avec le nom du transform pour éviter les collisions dans /tmp
      wrap="outputs/tmp/${base}_${transform}_wrap.c"
      obfc="${outdir}/${base}_obf.c"
      outbin="${outdir}/${base}_obf"

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

      # Base commune à toutes les exécutions : Environnement + Initialisation des Opaques
      TIGRESS_OPTS="--Environment=x86_64:Linux:Gcc --Seed=0"
      TIGRESS_OPTS="$TIGRESS_OPTS --Transform=InitEntropy"
      TIGRESS_OPTS="$TIGRESS_OPTS --Transform=InitOpaque --Functions=main --InitOpaqueStructs=list,array --InitOpaqueCount=2 --InitOpaqueSize=30"
      
      # Options spécifiques injectées selon le Transform en cours d'évaluation
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
          # Cas par défaut pour Split, Virtualize, etc.
          TIGRESS_OPTS="$TIGRESS_OPTS --Transform=$transform --Functions=*"
          ;;
      esac

      # Exécution dans Docker
      docker run --rm -v "$PWD:/work" -w /work psec/tigress:4 \
        bash -lc "tigress $TIGRESS_OPTS --out=${obfc} ${wrap} && gcc -O0 -g ${obfc} -o ${outbin}"
        
    done
  done
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

echo "[+] Nettoyage des fichiers intermédiaires"
# On supprime le dossier tmp qui contient tous les wrappers inutiles
rm -rf outputs/tmp

# On supprime les éventuels fichiers assembleur et objets laissés par movcc
rm -f outputs/movfuscator/*.o outputs/movfuscator/*.s

echo "[+] Compression des artefacts"
# Les binaires Movfuscator et les codes sources Tigress se compressent extrêmement bien.
# On crée une archive unique pour GitLab CI.
tar -czf outputs.tar.gz outputs/

echo "[+] Cleanup samples"
rm -f samples/*.c

echo "[+] Done"

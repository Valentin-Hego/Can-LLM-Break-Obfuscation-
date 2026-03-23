// --- arithmetic_14.c ---
#include <stdio.h>
int f(int n) { return n & 1; }
int main() {
  printf("%d (0=pair, 1=impair)\n", parite_binaire(7));
  return 0;
}

// --- arithmetic_07.c ---
#include <stdio.h>
int f(int L, int l) { return 2 * (L + l); }
int main() {
  printf("%d\n", f(5, 3));
  return 0;
}

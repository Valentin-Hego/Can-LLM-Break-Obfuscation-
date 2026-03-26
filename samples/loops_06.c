// --- loops_06.c ---
#include <stdio.h>
int f(int base, int exp) {
  int r = 1;
  while (exp--) {
    r *= base;
  }
  return r;
}
int main() {
  printf("%d\n", f(2, 5));
  return 0;
}

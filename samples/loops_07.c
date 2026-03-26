// --- loops_07.c ---
#include <stdio.h>
int f(int n) {
  int f = 1;
  int i;
  for (i = 2; i <= n; i++) {
    f *= i;
  }
  return f;
}
int main() {
  printf("%d\n", f(5));
  return 0;
}

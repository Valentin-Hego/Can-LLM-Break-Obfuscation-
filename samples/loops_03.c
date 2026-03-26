// --- loops_03.c ---
#include <stdio.h>
int f(int n) {
  int s = 0;
  int i;
  for (i = 1; i <= n; i++) {
    s += i;
  }
  return s;
}
int main() {
  printf("%d\n", f(10));
  return 0;
}

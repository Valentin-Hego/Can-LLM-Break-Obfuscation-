// --- loops_15.c ---
#include <stdio.h>
int f(int a, int b) {
  while (a != b) {
    if (a > b) {
      a -= b;
    } else {
      b -= a;
    }
  }
  return a;
}
int main() {
  printf("%d\n", f(48, 18));
  return 0;
}

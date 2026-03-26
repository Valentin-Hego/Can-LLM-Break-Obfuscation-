// --- loops_05.c ---
#include <stdio.h>
int f(int a, int b) {
  int r = 0;
  for (int i = 0; i < b; i++) {
    r += a;
  }
  return r;
}
int main() {
  printf("%d\n", f(4, 3));
  return 0;
}

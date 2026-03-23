// --- arithmetic_13.c ---
#include <stdio.h>
int f(int a, int b, int c) {
  int m = (a < b) ? a : b;
  return (m < c) ? m : c;
}
int main() {
  printf("%d\n", f(7, 3, 5));
  return 0;
}

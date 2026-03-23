// --- arithmetic_12.c ---
#include <stdio.h>
int f(int a, int b) { return (a > b) ? a : b; }
int main() {
  printf("%d\n", f(15, 8));
  return 0;
}

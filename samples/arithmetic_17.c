// --- arithmetic_17.c ---
#include <stdio.h>
void f(int a, int b) {
  a = a + b;
  b = a - b;
  a = a - b;
  printf("%d %d\n", a, b);
}
int main() {
  swap_arithmetique(5, 10);
  return 0;
}

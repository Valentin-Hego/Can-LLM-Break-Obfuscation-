// --- arithmetic_06.c ---
#include <stdio.h>
float f(int a, int b, int c) { return (a + b + c) / 3.0f; }
int main() {
  printf("%.2f\n", moyenne(4, 5, 8));
  return 0;
}

// --- arithmetic_04.c ---
#include <stdio.h>
float f(int a, int b) { return (float)a / b; }
int main() {
  printf("%.2f\n", division(10, 3));
  return 0;
}

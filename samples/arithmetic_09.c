// --- arithmetic_09.c ---
#include <stdio.h>
float f(float c) { return (c * 9.0f / 5.0f) + 32.0f; }
int main() {
  printf("%.2f\n", celsius_fahrenheit(25.0));
  return 0;
}

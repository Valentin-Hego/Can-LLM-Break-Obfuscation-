#include <stdio.h>

float f(float c) { return (c * 9.0f) / 5.0f + 32.0f; }

int main(int argc, char *argv[]) {
  float tmp = f(25.0f);
  printf("%.2f\n", (double)tmp);
  return 0;
}
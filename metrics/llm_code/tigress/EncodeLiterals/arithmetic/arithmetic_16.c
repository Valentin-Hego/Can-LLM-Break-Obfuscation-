#include <stdio.h>

int f(int n) { return n << 3; }

int main(int argc, char *argv[]) {
  int tmp = f(5);
  printf("5 * 8 = %d\n", tmp);
  return 0;
}
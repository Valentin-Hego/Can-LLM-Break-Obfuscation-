#include <stdio.h>

int f(int base, int exp) {
  int r = 1;
  while (exp--) {
    r *= base;
  }
  return r;
}

int main(int argc, char *argv[]) {
  int tmp = f(2, 5);
  printf("%d\n", tmp);
  return 0;
}
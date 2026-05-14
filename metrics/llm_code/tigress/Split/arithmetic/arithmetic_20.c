#include <stdio.h>
#include <stdlib.h>

int f(int n, int pos) { return n | (1 << pos); }

int main(int argc, char *argv[]) {
  int tmp = f(5, 1);
  printf("5 avec bit 1 a 1 : %d\n", tmp);
  return 0;
}
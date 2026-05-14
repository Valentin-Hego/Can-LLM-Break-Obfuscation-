#include <stdio.h>

int f(int L, int l) { return 2 * (L + l); }

int main(int argc, char *argv[]) {
  int tmp = f(5, 3);
  printf("%d\n", tmp);
  return 0;
}
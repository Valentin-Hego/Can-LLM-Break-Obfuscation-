#include <stdio.h>

void f(int *a, int *b) {
  int t = *a;
  *a = *b;
  *b = t;
}

int main(int argc, char *argv[]) {
  int x = 1;
  int y = 2;
  f(&x, &y);
  printf("%d %d\n", x, y);
  return 0;
}
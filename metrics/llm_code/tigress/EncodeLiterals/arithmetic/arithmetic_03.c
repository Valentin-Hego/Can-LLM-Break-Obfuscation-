#include <stdio.h>

int f(int a, int b) { return a * b; }

int main(int argc, char *argv[]) {
  int tmp = f(6, 7);
  printf("%d\n", tmp);
  return 0;
}
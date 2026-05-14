#include <stdio.h>

int f(int n) {
  if (n <= 1) {
    return 1;
  }
  return n * f(n - 1);
}

int main(int argc, char *argv[]) {
  int tmp = f(5);
  printf("%d\n", tmp);
  return 0;
}
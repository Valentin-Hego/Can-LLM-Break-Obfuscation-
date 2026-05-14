#include <stdio.h>

int f(int n) {
  int r = 0;
  while (n > 0) {
    r = r * 10 + n % 10;
    n /= 10;
  }
  return r;
}

int main(int argc, char *argv[]) {
  int tmp = f(456);
  printf("%d\n", tmp);
  return 0;
}
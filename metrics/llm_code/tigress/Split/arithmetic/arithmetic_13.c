#include <stdio.h>

int f(int a, int b, int c) {
  int m;
  if (a < b) {
    m = a;
  } else {
    m = b;
  }
  if (m < c) {
    return m;
  } else {
    return c;
  }
}

int main(int argc, char *argv[]) {
  int tmp = f(7, 3, 5);
  printf("%d\n", tmp);
  return 0;
}
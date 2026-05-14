#include <stdio.h>

void f(int n) {
  int a = 0;
  int b = 1;
  int c;
  for (int i = 0; i < n; i++) {
    printf("%d ", a);
    c = a + b;
    a = b;
    b = c;
  }
  printf("\n");
}

int main(int argc, char *argv[]) {
  f(8);
  return 0;
}
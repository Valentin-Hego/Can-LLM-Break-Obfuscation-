#include <stdio.h>

void f(int n) {
  for (int i = 1; i <= n; i++) {
    printf("%d ", i);
  }
  printf("\n");
}

int main(int argc, char *argv[]) {
  f(5);
  return 0;
}
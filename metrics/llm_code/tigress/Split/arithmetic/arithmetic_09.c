#include <stdio.h>
#include <stdlib.h>

void f(int x) {
  int result = (x * 9) + 3;
  printf("%d\n", result);
}

int main(int argc, char *argv[]) {
  if (argc > 1) {
    f(atoi(argv[1]));
  }
  return 0;
}
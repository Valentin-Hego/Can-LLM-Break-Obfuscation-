#include <stdio.h>

void g() { printf("Pendant.\n"); }

void f(void (*func)()) {
  printf("Avant.\n");
  func();
  printf("Apres.\n");
}

int main(int argc, char *argv[]) {
  f(&g);
  return 0;
}
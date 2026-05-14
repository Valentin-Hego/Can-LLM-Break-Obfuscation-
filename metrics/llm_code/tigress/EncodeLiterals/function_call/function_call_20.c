#include <stdio.h>

int f(int a, int b) { return a + b; }

int g(int a, int b) { return a - b; }

int main(int argc, char *argv[]) {
  int (*ops[2])(int, int);
  ops[0] = f;
  ops[1] = g;
  printf("Add:%d Sub:%d\n", ops[0](5, 2), ops[1](5, 2));
  return 0;
}
#include <stdio.h>

void f() { printf("Action effectuee.\n"); }

void executer() { f(); }

int main(int argc, char *argv[]) {
  f();
  return 0;
}
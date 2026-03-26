// --- function_call_19.c ---
#include <stdio.h>
void f(void (*f)()) {
  printf("Avant.\n");
  f();
  printf("Apres.\n");
}
void g() { printf("Pendant.\n"); }
int main() {
  f(g);
  return 0;
}

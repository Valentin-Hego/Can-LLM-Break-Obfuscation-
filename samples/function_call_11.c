// --- function_call_11.c ---
#include <stdio.h>
int *f(int *a, int *b) { return (*a > *b) ? a : b; }
int main() {
  int x = 5, y = 10;
  printf("%d\n", *f(&x, &y));
  return 0;
}

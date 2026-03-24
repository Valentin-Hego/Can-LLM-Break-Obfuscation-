// --- function_call_07.c ---
#include <stdio.h>
void f(int *a, int *b) {
  int t = *a;
  *a = *b;
  *b = t;
}
int main() {
  int x = 1, y = 2;
  f(&x, &y);
  printf("%d %d\n", x, y);
  return 0;
}

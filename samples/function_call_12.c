// --- function_call_12.c ---
#include <stdio.h>
void f(int n) {
  if (n == 0)
    return;
  printf("%d ", n);
  f(n - 1);
}
int main() {
  f(3);
  printf("\n");
  return 0;
}

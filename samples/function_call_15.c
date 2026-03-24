// --- function_call_15.c ---
#include <stdio.h>
int f(int n) {
  if (n <= 1)
    return n;
  return f(n - 1) + f(n - 2);
}
int main() {
  printf("%d\n", f(6));
  return 0;
}

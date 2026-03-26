// --- function_call_13.c ---
#include <stdio.h>
int f(int n) {
  if (n == 0) {
    return 0;
  }
  return n + f(n - 1);
}
int main() {
  printf("%d\n", f(5));
  return 0;
}

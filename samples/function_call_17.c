// --- function_call_17.c ---
#include <stdio.h>
int f(int n) {
  if (n == 0)
    return 0;
  return (n % 10) + f(n / 10);
}
int main() {
  printf("%d\n", f(123));
  return 0;
}

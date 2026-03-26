// --- function_call_16.c ---
#include <stdio.h>
int f(int a, int b) {
  if (b == 0) {
    return a;
  }
  return f(b, a % b);
}
int main() {
  printf("%d\n", f(48, 18));
  return 0;
}

// --- function_call_18.c ---
#include <stdio.h>
int f(int n);
int g(int n) {
  if (n == 0)
    return 1;
  return f(n - 1);
}
int f(int n) {
  if (n == 0)
    return 0;
  return g(n - 1);
}
int main() {
  printf("4 pair ? %d\n", g(4));
  return 0;
}

// --- loops_17.c ---
#include <stdio.h>
void f(int n) {
  int a = 0, b = 1, c;
  for (int i = 0; i < n; i++) {
    printf("%d ", a);
    c = a + b;
    a = b;
    b = c;
  }
  printf("\n");
}
int main() {
  f(8);
  return 0;
}

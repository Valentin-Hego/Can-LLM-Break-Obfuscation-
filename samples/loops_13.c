// --- loops_13.c ---
#include <stdio.h>
void f(int n) {
  for (int i = 1; i <= n; i++) {
    for (int j = 0; j < i; j++)
      printf("*");
    printf("\n");
  }
}
int main() {
  f(4);
  return 0;
}

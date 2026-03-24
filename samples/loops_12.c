// --- loops_12.c ---
#include <stdio.h>
void f(int n) {
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++)
      printf("*");
    printf("\n");
  }
}
int main() {
  f(3);
  return 0;
}

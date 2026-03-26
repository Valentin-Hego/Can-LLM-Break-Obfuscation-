// --- loops_13.c ---
#include <stdio.h>
void f(int n) {
  int i;
  for (i = 1; i <= n; i++) {
    int j;
    for (j = 0; j < i; j++) {
      printf("*");
    }
    printf("\n");
  }
}
int main() {
  f(4);
  return 0;
}

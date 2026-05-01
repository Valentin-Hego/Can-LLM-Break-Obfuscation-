// --- loops_11.c ---
#include <stdio.h>
void f(int n) {
  int i;
  for (i = 0; i < n; i++) {
    printf("*");
  }
  printf("\n");
}
int main() {
  f(5);
  return 0;
}

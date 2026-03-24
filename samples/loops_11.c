// --- loops_11.c ---
#include <stdio.h>
void f(int n) {
  for (int i = 0; i < n; i++)
    printf("*");
  printf("\n");
}
int main() {
  f(5);
  return 0;
}

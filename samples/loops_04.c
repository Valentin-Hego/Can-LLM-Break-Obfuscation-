// --- loops_04.c ---
#include <stdio.h>
void f(int n) {
  for (int i = 2; i <= n; i += 2) {
    printf("%d ", i);
  }
  printf("\n");
}
int main() {
  f(10);
  return 0;
}

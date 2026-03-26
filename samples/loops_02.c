// --- loops_02.c ---
#include <stdio.h>
void f(int n) {
  while (n > 0) {
    printf("%d ", n--);
  }
  printf("\n");
}
int main() {
  f(5);
  return 0;
}

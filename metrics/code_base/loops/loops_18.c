// --- loops_18.c ---
#include <stdio.h>
void f(int n) {
  while (n > 0) {
    printf("%d", n % 2);
    n /= 2;
  }
  printf("\n");
}
int main() {
  f(13);
  return 0;
}

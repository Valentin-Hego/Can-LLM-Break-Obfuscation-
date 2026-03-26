// --- loops_08.c ---
#include <stdio.h>
int f(int n) {
  int c = 0;
  do {
    c++;
    n /= 10;
  } while (n != 0);
  return c;
}
int main() {
  printf("%d\n", f(12345));
  return 0;
}

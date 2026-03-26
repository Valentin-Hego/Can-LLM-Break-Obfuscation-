// --- loops_19.c ---
#include <stdio.h>
int f(int n) {
  int l = 1;
  while (n != 1) {
    n = (n % 2 == 0) ? n / 2 : n * 3 + 1;
    l++;
  }
  return l;
}
int main() {
  printf("%d\n", f(12));
  return 0;
}

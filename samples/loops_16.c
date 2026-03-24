// --- loops_16.c ---
#include <stdio.h>
int f(int a, int b) {
  int max = (a > b) ? a : b;
  while (max % a != 0 || max % b != 0)
    max++;
  return max;
}
int main() {
  printf("%d\n", f(3, 15));
  return 0;
}
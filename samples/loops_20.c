// --- loops_20.c ---
#include <stdio.h>
int f(int n) {
  int s = 0;
  for (int i = 1; i < n; i++)
    if (n % i == 0)
      s += i;
  return s == n;
}
int main() {
  printf("28 est parfait ? %d\n", est_parfait(28));
  return 0;
}

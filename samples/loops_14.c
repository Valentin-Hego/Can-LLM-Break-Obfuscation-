// --- loops_14.c ---
#include <stdio.h>
int f(int n) {
  if (n <= 1)
    return 0;
  for (int i = 2; i * i <= n; i++)
    if (n % i == 0) {
      return 0;
    }
  return 1;
}
int main() {
  printf("%d\n", f(29));
  return 0;
}

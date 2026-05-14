#include <stdio.h>

int f(int n) {
  int s = 0;
  for (int i = 1; i < n; i++) {
    if (n % i == 0) {
      s += i;
    }
  }
  return s == n;
}

int main(int argc, char *argv[]) {
  int tmp = f(28);
  printf("28 est parfait ? %d\n", tmp);
  return 0;
}
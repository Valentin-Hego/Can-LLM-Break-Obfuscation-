// --- loops_12.c ---
#include <stdio.h>
void f(int n) {
  int i;
  for (i = 0; i < n; i++) {
    int j;
    for (j = 0; j < n; j++) {
      printf("*");
    }
    printf("\n");
  }
}
int main() {
  f(3);
  return 0;
}

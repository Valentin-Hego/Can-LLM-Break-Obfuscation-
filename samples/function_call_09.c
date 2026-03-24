// --- function_call_09.c ---
#include <stdio.h>
void f(int *arr, int taille) {
  for (int i = 0; i < taille; i++)
    arr[i] = 0;
}
int main() {
  int t[] = {1, 2, 3};
  f(t, 3);
  printf("%d\n", t[0]);
  return 0;
}

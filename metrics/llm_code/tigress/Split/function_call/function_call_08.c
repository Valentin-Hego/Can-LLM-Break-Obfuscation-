#include <stdio.h>

int f(int *arr, int taille) {
  int s = 0;
  int i = 0;
  while (i < taille) {
    s += arr[i];
    i++;
  }
  return s;
}

int main(int argc, char *argv[]) {
  int t[3];
  t[0] = 1;
  t[1] = 2;
  t[2] = 3;
  int tmp = f(t, 3);
  printf("%d\n", tmp);
  return 0;
}
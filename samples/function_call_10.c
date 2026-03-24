// --- function_call_10.c ---
#include <stdio.h>
int f(char *str) {
  int l = 0;
  while (str[l] != '\0')
    l++;
  return l;
}
int main() {
  printf("%d\n", f("Hello"));
  return 0;
}

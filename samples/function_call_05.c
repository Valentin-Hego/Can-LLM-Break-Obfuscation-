// --- function_call_05.c ---
#include <stdio.h>
void f(int n)
{
  n = 99;
}
int main()
{
  int x = 5;
  f(x);
  printf("%d\n", x);
  return 0;
}

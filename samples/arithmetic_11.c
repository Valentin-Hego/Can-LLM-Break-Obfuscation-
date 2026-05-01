// --- arithmetic_11.c ---
#include <stdio.h>
int f(int n)
{
  return (n < 0) ? -n : n;
}
int main()
{
  printf("%d\n", f(-42));
  return 0;
}

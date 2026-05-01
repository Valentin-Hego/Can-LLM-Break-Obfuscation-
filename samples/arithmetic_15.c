// --- arithmetic_15.c ---
#include <stdio.h>
int f(int n)
{
  return 1 << n;
}
int main()
{
  printf("2^4 = %d\n", f(4));
  return 0;
}

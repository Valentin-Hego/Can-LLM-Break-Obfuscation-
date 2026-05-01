// --- arithmetic_16.c ---
#include <stdio.h>
int f(int n)
{
  return n << 3;
}
int main()
{
  printf("5 * 8 = %d\n", f(5));
  return 0;
}

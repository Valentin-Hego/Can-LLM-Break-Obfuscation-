// --- arithmetic_10.c ---
#include <stdio.h>
int f(int a, int b, int c)
{
  return (b * b) - (4 * a * c);
}
int main()
{
  printf("%d\n", f(2, 5, -3));
  return 0;
}

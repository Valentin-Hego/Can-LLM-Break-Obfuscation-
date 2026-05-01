// --- arithmetic_20.c ---
#include <stdio.h>
int f(int n, int pos)
{
  return n | (1 << pos);
}
int main()
{
  printf("5 avec bit 1 a 1 : %d\n", f(5, 1));
  return 0;
}

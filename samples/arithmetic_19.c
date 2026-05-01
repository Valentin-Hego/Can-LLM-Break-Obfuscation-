// --- arithmetic_19.c ---
#include <stdio.h>
int f(int n, int pos)
{
  return (n >> pos) & 1;
}
int main()
{
  printf("Bit 2 de 5 (101) : %d\n", f(5, 2));
  return 0;
}

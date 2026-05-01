#include <stdio.h>

void f(int n)
{
    int i;

    i = 1;
    while (i <= n)
    {
        printf("%d ", i);
        i++;
    }
    putchar('\n');
}
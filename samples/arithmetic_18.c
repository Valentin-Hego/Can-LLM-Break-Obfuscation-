// --- arithmetic_18.c ---
#include <stdio.h>
void swap_xor(int a, int b) { a^=b; b^=a; a^=b; printf("%d %d\n",a,b); }
int main() { swap_xor(5, 10); return 0; }


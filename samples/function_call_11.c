// --- function_call_11.c ---
#include <stdio.h>
int* max_pointeur(int *a, int *b) { return (*a > *b) ? a : b; }
int main() { int x=5, y=10; printf("%d\n", *max_pointeur(&x, &y)); return 0; }


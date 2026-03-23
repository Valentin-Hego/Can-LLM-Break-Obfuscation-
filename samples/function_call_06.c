// --- function_call_06.c ---
#include <stdio.h>
void modifier_ref(int *n) { *n = 99; }
int main() { int x = 5; modifier_ref(&x); printf("%d\n", x); return 0; }


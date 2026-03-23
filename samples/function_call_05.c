// --- function_call_05.c ---
#include <stdio.h>
void modifier_valeur(int n) { n = 99; }
int main() { int x = 5; modifier_valeur(x); printf("%d\n", x); return 0; }


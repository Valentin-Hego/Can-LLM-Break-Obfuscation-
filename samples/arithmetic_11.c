// --- arithmetic_11.c ---
#include <stdio.h>
int val_absolue(int n) { return (n < 0) ? -n : n; }
int main() { printf("%d\n", val_absolue(-42)); return 0; }


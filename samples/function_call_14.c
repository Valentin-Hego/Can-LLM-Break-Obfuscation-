// --- function_call_14.c ---
#include <stdio.h>
int rec_factorielle(int n) { if(n<=1) return 1; return n * rec_factorielle(n-1); }
int main() { printf("%d\n", rec_factorielle(5)); return 0; }


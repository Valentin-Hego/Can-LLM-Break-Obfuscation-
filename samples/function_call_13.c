// --- function_call_13.c ---
#include <stdio.h>
int rec_somme(int n) { if(n==0) return 0; return n + rec_somme(n-1); }
int main() { printf("%d\n", rec_somme(5)); return 0; }


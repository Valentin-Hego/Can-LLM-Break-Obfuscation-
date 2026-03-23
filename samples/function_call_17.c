// --- function_call_17.c ---
#include <stdio.h>
int rec_somme_chiffres(int n) { if(n==0) return 0; return (n%10) + rec_somme_chiffres(n/10); }
int main() { printf("%d\n", rec_somme_chiffres(123)); return 0; }


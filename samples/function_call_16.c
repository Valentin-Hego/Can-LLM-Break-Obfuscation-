// --- function_call_16.c ---
#include <stdio.h>
int rec_pgcd(int a, int b) { if(b==0) return a; return rec_pgcd(b, a%b); }
int main() { printf("%d\n", rec_pgcd(48, 18)); return 0; }


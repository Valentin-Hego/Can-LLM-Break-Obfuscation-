// --- function_call_18.c ---
#include <stdio.h>
int est_impair(int n);
int est_pair(int n) { if(n==0) return 1; return est_impair(n-1); }
int est_impair(int n) { if(n==0) return 0; return est_pair(n-1); }
int main() { printf("4 pair ? %d\n", est_pair(4)); return 0; }


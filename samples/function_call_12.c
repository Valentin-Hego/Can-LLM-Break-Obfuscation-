// --- function_call_12.c ---
#include <stdio.h>
void rec_rebours(int n) { if(n==0) return; printf("%d ", n); rec_rebours(n-1); }
int main() { rec_rebours(3); printf("\n"); return 0; }


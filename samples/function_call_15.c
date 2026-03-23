// --- function_call_15.c ---
#include <stdio.h>
int rec_fibonacci(int n) { if(n<=1) return n; return rec_fibonacci(n-1) + rec_fibonacci(n-2); }
int main() { printf("%d\n", rec_fibonacci(6)); return 0; }


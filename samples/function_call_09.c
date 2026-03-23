// --- function_call_09.c ---
#include <stdio.h>
void reset_tableau(int *arr, int taille) { for(int i=0;i<taille;i++) arr[i]=0; }
int main() { int t[]={1,2,3}; reset_tableau(t, 3); printf("%d\n", t[0]); return 0; }


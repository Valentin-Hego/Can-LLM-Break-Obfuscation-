// --- function_call_10.c ---
#include <stdio.h>
int taille_chaine(char *str) { int l=0; while(str[l]!='\0') l++; return l; }
int main() { printf("%d\n", taille_chaine("Hello")); return 0; }


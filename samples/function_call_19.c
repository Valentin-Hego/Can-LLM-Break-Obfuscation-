// --- function_call_19.c ---
#include <stdio.h>
void exec_callback(void (*f)()) { printf("Avant.\n"); f(); printf("Apres.\n"); }
void ma_fonction() { printf("Pendant.\n"); }
int main() { exec_callback(ma_fonction); return 0; }


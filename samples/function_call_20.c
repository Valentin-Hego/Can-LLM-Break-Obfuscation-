// --- function_call_20.c ---
#include <stdio.h>
int add(int a, int b) { return a + b; }
int sub(int a, int b) { return a - b; }
int main()
{
    int (*ops[2])(int, int) = {add, sub};
    printf("Add:%d Sub:%d\n", ops[0](5, 2), ops[1](5, 2));
    return 0;
}

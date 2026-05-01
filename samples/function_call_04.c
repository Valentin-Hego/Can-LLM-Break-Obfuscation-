// --- function_call_04.c ---
#include <stdio.h>
void f()
{
  printf("Action effectuee.\n");
}
void executer() { f(); }
int main()
{
  f();
  return 0;
}

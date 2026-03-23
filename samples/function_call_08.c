#include <stdio.h>

int somme_tableau(int arr[], int taille)
{
    int s = 0;
    int i;

    for (i = 0; i < taille; i++)
        s += arr[i];

    return s;
}

int main()
{
    int t[] = {1, 2, 3};
    printf("%d\n", somme_tableau(t, 3));
    return 0;
}
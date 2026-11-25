#include <stdio.h>

__attribute__((noinline)) static long prime(long *address)
{
    long *previous = address;
    return *previous;
}

__attribute__((noinline)) static void damage(long *address)
{
#ifdef FIXED
    long *pointer = address;
    /* The intended operation preserves the correct value. */
    *pointer = 15;
#else
    (void)address;
    long *pointer;
    *pointer = 12;
#endif
}

__attribute__((noinline)) static long process(long initial)
{
    long value = initial;
    prime(&value);
    damage(&value);
    return value;
}

int main(void)
{
    printf("%ld\n", process(15));
    return 0;
}

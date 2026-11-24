#include <stdio.h>

static long calculate(long value, long adjustment)
{
    long result = value + adjustment;
    return result;
}

static long process(long input, long adjustment)
{
#ifdef FIXED
    return calculate(input, adjustment);
#else
    (void)adjustment;
    return calculate(input, 2);
#endif
}

int main(void)
{
    printf("%ld\n", process(10, 5));
    return 0;
}

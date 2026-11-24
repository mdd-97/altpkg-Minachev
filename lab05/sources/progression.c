#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

static int parse(const char *text, long *result)
{
    char *end;
    errno = 0;
    *result = strtol(text, &end, 10);
    return end != text && *end == '\0' && errno == 0;
}

static void emit(unsigned long index, long value)
{
    (void)index;
    printf("%ld\n", value);
}

int main(int argc, char **argv)
{
    long first = 0;
    long last = 0;
    long step = 1;
    if (argc == 1) {
        puts("Usage: progression LAST | FIRST LAST [STEP]");
        return 0;
    }

    int valid = argc == 2 ? parse(argv[1], &last) :
                argc <= 4 && parse(argv[1], &first) && parse(argv[2], &last);
    if (argc == 4)
        valid = valid && parse(argv[3], &step);
    if (!valid || step == 0 || (first < last && step < 0) ||
        (first > last && step > 0)) {
        fputs("Invalid range or step\n", stderr);
        return 2;
    }

    unsigned long index = 0;
    for (long value = first;;) {
        long next;
        emit(index, value);
        if (__builtin_add_overflow(value, step, &next) ||
            (step > 0 ? next > last : next < last))
            break;
        value = next;
        ++index;
    }
    return 0;
}

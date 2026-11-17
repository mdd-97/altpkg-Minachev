#include <stdio.h>
#include "args.h"

void print_arg(const char *arg)
{
    printf("%u: %s\n", ++counter, arg);
}

void print_help(void)
{
    fputs("rdsu-args " VERSION "\nUsage: rdsu-args ARG...\n", stderr);
}

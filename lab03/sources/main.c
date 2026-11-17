#include <stdio.h>
#include "args.h"

int main(int argc, char **argv)
{
    counter = 0;
    if (argc == 1) {
        print_help();
        return 0;
    }

    puts("BEGIN");
    for (int index = 1; index < argc; ++index)
        print_arg(argv[index]);
    puts("END");
    return 0;
}

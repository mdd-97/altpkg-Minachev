#include "../drivers/screen.h"

static void int_to_ascii(int n, char *str) {
    char tmp[12]; int i = 0, j = 0;
    if (n == 0) tmp[i++] = '0';
    while (n > 0) { tmp[i++] = '0' + n % 10; n /= 10; }
    while (i > 0) str[j++] = tmp[--i];
    str[j] = 0;
}

void main(void) {
    clear_screen();
    kprint("Welcome to My OS!\n");
    kprint("This is a text spanning multiple lines to test the newline handling.\n");
    kprint("Let's try scrolling...\n");
    char num[12];
    for (int i = 1; i <= 30; i++) {
        kprint("Line "); int_to_ascii(i, num); kprint(num); kprint("\n");
    }
    kprint("Backspace test: ABCX");
    kprint("\bD\n");
    for (;;) __asm__ volatile("hlt");
}

#include "ports.h"

/* Чтение байта из порта: in al, dx */
unsigned char port_byte_in(unsigned short port) {
    unsigned char result;
    __asm__ volatile("in %%dx, %%al" : "=a"(result) : "d"(port));
    return result;
}

/* Запись байта в порт: out dx, al */
void port_byte_out(unsigned short port, unsigned char data) {
    __asm__ volatile("out %%al, %%dx" : : "a"(data), "d"(port));
}

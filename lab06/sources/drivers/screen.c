#include "screen.h"
#include "ports.h"

/* Байтовое смещение ячейки (col,row) в видеопамяти: каждая ячейка = 2 байта */
int get_offset(int col, int row) { return 2 * (row * MAX_COLS + col); }

/* Курсор хранится в регистрах VGA 14 (старший байт) и 15 (младший) */
int get_cursor_offset(void) {
    port_byte_out(REG_SCREEN_CTRL, 14);
    int offset = port_byte_in(REG_SCREEN_DATA) << 8;
    port_byte_out(REG_SCREEN_CTRL, 15);
    offset += port_byte_in(REG_SCREEN_DATA);
    return offset * 2;
}

void set_cursor_offset(int offset) {
    if (offset < 0 || offset >= MAX_ROWS * MAX_COLS * 2 || offset % 2) return;
    offset /= 2;
    port_byte_out(REG_SCREEN_CTRL, 14);
    port_byte_out(REG_SCREEN_DATA, (unsigned char)(offset >> 8));
    port_byte_out(REG_SCREEN_CTRL, 15);
    port_byte_out(REG_SCREEN_DATA, (unsigned char)(offset & 0xff));
}

static void memory_copy(volatile unsigned char *source, volatile unsigned char *dest, int no_bytes) {
    for (int i = 0; i < no_bytes; i++)
        dest[i] = source[i];
}

void print_char(char character, int col, int row, char attribute_byte) {
    volatile unsigned char *vidmem = (volatile unsigned char *)VIDEO_ADDRESS;
    if (!attribute_byte) attribute_byte = WHITE_ON_BLACK;

    int offset;
    if (col == -1 && row == -1) offset = get_cursor_offset();
    else if (col >= 0 && col < MAX_COLS && row >= 0 && row < MAX_ROWS)
        offset = get_offset(col, row);
    else return;
    if (offset < 0 || offset >= MAX_ROWS * MAX_COLS * 2 || offset % 2) return;

    if (character == '\n') {
        int rows = offset / (2 * MAX_COLS);
        offset = get_offset(0, rows + 1);
    } else if (character == '\b') {
        /* Backspace (сам. задание 2): шаг назад, затираем пробелом */
        if (offset >= 2) {
            offset -= 2;
            vidmem[offset] = ' ';
            vidmem[offset + 1] = attribute_byte;
        }
    } else {
        vidmem[offset] = character;
        vidmem[offset + 1] = attribute_byte;
        offset += 2;
    }

    /* Скроллинг: вышли за последнюю строку -> сдвигаем строки 1..24 на 0..23 */
    if (offset >= MAX_ROWS * MAX_COLS * 2) {
        for (int i = 1; i < MAX_ROWS; i++)
            memory_copy((volatile unsigned char *)(get_offset(0, i) + VIDEO_ADDRESS),
                        (volatile unsigned char *)(get_offset(0, i - 1) + VIDEO_ADDRESS),
                        MAX_COLS * 2);
        volatile unsigned char *last_line = (volatile unsigned char *)(get_offset(0, MAX_ROWS - 1) + VIDEO_ADDRESS);
        for (int i = 0; i < MAX_COLS * 2; i += 2) {
            last_line[i] = ' ';
            last_line[i + 1] = WHITE_ON_BLACK;
        }
        offset -= 2 * MAX_COLS;
    }
    set_cursor_offset(offset);
}

void kprint_at(char *message, int col, int row) {
    if (col == -1 && row == -1) { /* Текущий курсор. */ }
    else if (col >= 0 && col < MAX_COLS && row >= 0 && row < MAX_ROWS)
        set_cursor_offset(get_offset(col, row));
    else return;
    for (int i = 0; message[i] != 0; i++)
        print_char(message[i], -1, -1, 0);
}

void kprint(char *message) { kprint_at(message, -1, -1); }

void kprint_attr(char *message, char attr) {
    for (int i = 0; message[i] != 0; i++)
        print_char(message[i], -1, -1, attr);
}

/* Сам. задание 1: очистка — пишем пробел+атрибут во все 2000 ячеек, курсор в 0 */
void clear_screen(void) {
    volatile unsigned char *vidmem = (volatile unsigned char *)VIDEO_ADDRESS;
    for (int i = 0; i < MAX_COLS * MAX_ROWS; i++) {
        vidmem[i * 2] = ' ';
        vidmem[i * 2 + 1] = WHITE_ON_BLACK;
    }
    set_cursor_offset(0);
}

/* Сам. задание 3: красный фон, сообщение, остановка CPU навсегда */
void kpanic(char *message) {
    kprint_attr("KERNEL PANIC: ", WHITE_ON_RED);
    kprint_attr(message, WHITE_ON_RED);
    __asm__ volatile("cli");          /* запрещаем прерывания */
    for (;;) __asm__ volatile("hlt"); /* hlt без прерываний = вечная остановка */
}

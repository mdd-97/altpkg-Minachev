#ifndef SCREEN_H
#define SCREEN_H

#define VIDEO_ADDRESS 0xb8000
#define MAX_ROWS 25
#define MAX_COLS 80
#define WHITE_ON_BLACK 0x0f
#define WHITE_ON_RED   0x4f

/* Порты VGA-контроллера */
#define REG_SCREEN_CTRL 0x3d4
#define REG_SCREEN_DATA 0x3d5

/* Смещения задаются в байтах; видимые ячейки имеют индексы 0..1999. */
int get_offset(int col, int row);
int get_cursor_offset(void);
void set_cursor_offset(int offset);
void clear_screen(void);
void kprint(char *message);
void kprint_at(char *message, int col, int row);
void kprint_attr(char *message, char attr);
void print_char(char character, int col, int row, char attribute_byte);
void kpanic(char *message);

#endif

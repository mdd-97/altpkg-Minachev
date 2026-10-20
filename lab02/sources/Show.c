/* Show — постраничный просмотр текстового файла (ncurses).
 * Пробел — страница вперёд, q — выход. */
#define _POSIX_C_SOURCE 200809L   /* для getline() и strdup() */
#include <curses.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

static char **lines = NULL;   /* файл целиком в памяти: массив строк */
static size_t nlines = 0;

static void free_lines(void)
{
    for (size_t i = 0; i < nlines; i++)
        free(lines[i]);
    free(lines);
}

/* Прочитать файл в память. 0 — успех, -1 — ошибка (errno сохранён). */
static int load(const char *path)
{
    FILE *f = fopen(path, "r");
    if (f == NULL)
        return -1;

    char *buf = NULL;
    size_t cap = 0, alloc = 0;
    ssize_t len;
    while ((len = getline(&buf, &cap, f)) != -1) {
        if (len > 0 && buf[len - 1] == '\n')
            buf[len - 1] = '\0';
        if (nlines == alloc) {
            alloc = alloc ? alloc * 2 : 64;
            char **p = realloc(lines, alloc * sizeof *lines);
            if (p == NULL) {
                free(buf);
                fclose(f);
                return -1;
            }
            lines = p;
        }
        if ((lines[nlines] = strdup(buf)) == NULL) {
            free(buf);
            fclose(f);
            return -1;
        }
        nlines++;
    }
    int err = ferror(f) ? errno : 0;   /* например, EISDIR при попытке читать каталог */
    free(buf);
    fclose(f);
    if (err) {
        errno = err;
        return -1;
    }
    return 0;
}

/* Вывести в окно страницу, начиная со строки top; длинные строки усекаются по ширине окна. */
static void draw(WINDOW *w, size_t top)
{
    int h, wd;
    getmaxyx(w, h, wd);
    werase(w);
    for (int i = 0; i < h && top + (size_t)i < nlines; i++)
        mvwaddnstr(w, i, 0, lines[top + i], wd);
    wrefresh(w);
}

int main(int argc, char **argv)
{
    /* Ошибки диагностируются до initscr(): терминал в экранный режим не переводится. */
    if (argc != 2) {
        fprintf(stderr, "Usage: %s FILE\n", argv[0]);
        return 1;
    }
    if (load(argv[1]) != 0) {
        fprintf(stderr, "%s: %s: %s\n", argv[0], argv[1], strerror(errno));
        free_lines();
        return 2;
    }

    initscr();            /* инициализация ncurses, создание stdscr */
    noecho();             /* не отображать вводимые символы */
    cbreak();             /* символы поступают сразу, без ожидания Enter */

    mvprintw(0, 0, "%.*s", COLS, argv[1]);   /* имя файла в первой строке экрана */
    refresh();

    WINDOW *w = newwin(LINES - 1, COLS, 1, 0);   /* окно вывода под строкой заголовка */
    keypad(w, TRUE);                             /* функциональные клавиши в окне вывода */

    size_t top = 0;
    size_t page = (size_t)(LINES - 1);
    draw(w, top);

    int ch;
    while ((ch = wgetch(w)) != 'q') {
        if (ch == ' ' && top + page < nlines) {
            top += page;
            draw(w, top);
        }
    }

    delwin(w);            /* освобождение окна */
    endwin();             /* восстановление режима терминала */
    free_lines();
    return 0;
}

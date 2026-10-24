# Сборка программы Show
CC = gcc
CFLAGS = -Wall -O2
LDLIBS = -lncurses

# цель по умолчанию (первая в файле): исполняемый файл
Show: Show.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

Show.o: Show.c
	$(CC) $(CFLAGS) -c -o $@ $<

# удаление продуктов сборки
clean:
	rm -f Show Show.o

.PHONY: clean

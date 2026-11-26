C_SOURCES = $(wildcard kernel/*.c drivers/*.c)
HEADERS   = $(wildcard kernel/*.h drivers/*.h)
OBJ       = $(C_SOURCES:.c=.o)
NASM ?= nasm

CC      = gcc
CFLAGS  = -m32 -ffreestanding -fno-pie -fno-pic -fno-stack-protector -fno-builtin \
          -fno-asynchronous-unwind-tables -nostdlib -Wall -Wextra -Werror -Wno-main -std=gnu11 -c
LD      = ld
OBJCOPY = objcopy
QEMU    = qemu-system-x86_64

.PHONY: all run clean

all: os-image.bin

run: os-image.bin
	$(QEMU) -drive format=raw,file=$<

# Образ = загрузчик (1 сектор) + ядро, добитое нулями до 32 секторов
os-image.bin: boot/bootsect.bin kernel.bin
	test "$$(wc -c < kernel.bin)" -le 15872
	cat $^ > $@
	truncate -s 16384 $@

kernel.elf: boot/kernel_entry.o $(OBJ) linker.ld
	$(LD) -m elf_i386 -T linker.ld -o $@ boot/kernel_entry.o $(OBJ)

kernel.bin: kernel.elf
	$(OBJCOPY) -O binary $< $@

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) $< -o $@

boot/kernel_entry.o: boot/kernel_entry.asm
	$(NASM) $< -f elf32 -o $@

boot/bootsect.bin: boot/bootsect.asm boot/*.asm
	$(NASM) $< -f bin -o $@

clean:
	rm -f *.bin *.elf *.o boot/*.bin boot/*.o kernel/*.o drivers/*.o tests/*.o

# Тестовые ядра используют тот же драйвер, но отдельную точку main.
check-kernel.elf: boot/kernel_entry.o tests/kernel_checks.o drivers/screen.o drivers/ports.o linker.ld
	$(LD) -m elf_i386 -T linker.ld -o $@ boot/kernel_entry.o tests/kernel_checks.o drivers/screen.o drivers/ports.o

check-kernel.bin: check-kernel.elf
	$(OBJCOPY) -O binary $< $@

check-image.bin: boot/bootsect.bin check-kernel.bin
	test "$$(wc -c < check-kernel.bin)" -le 15872
	cat $^ > $@
	truncate -s 16384 $@

# Аварийный вариант имеет отдельный объект: смена флага не оставляет stale .o.
tests/kernel_panic.o: tests/kernel_checks.c $(HEADERS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -DPANIC_TEST $< -o $@

panic-kernel.elf: boot/kernel_entry.o tests/kernel_panic.o drivers/screen.o drivers/ports.o linker.ld
	$(LD) -m elf_i386 -T linker.ld -o $@ boot/kernel_entry.o tests/kernel_panic.o drivers/screen.o drivers/ports.o

panic-kernel.bin: panic-kernel.elf
	$(OBJCOPY) -O binary $< $@

panic-image.bin: boot/bootsect.bin panic-kernel.bin
	test "$$(wc -c < panic-kernel.bin)" -le 15872
	cat $^ > $@
	truncate -s 16384 $@

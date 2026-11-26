; Загрузчик: читает ядро с диска в 0x1000, переходит в 32 бит, прыгает в ядро
[org 0x7c00]
KERNEL_OFFSET equ 0x1000

    jmp 0:start
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000
    mov bp, sp
    cld
    sti
    mov [BOOT_DRIVE], dl    ; BIOS кладёт номер загрузочного диска в dl

    ; Явно выбираем VGA 80x25, цветной текстовый режим BIOS 3.
    mov ax, 0x0003
    int 0x10
    mov bx, MSG_REAL_MODE
    call print_string
    call print_nl

    call load_kernel
    call switch_to_pm
    jmp $

%include "boot/print_string.asm"
%include "boot/disk_load.asm"
%include "boot/gdt.asm"
%include "boot/switch_to_pm.asm"

[bits 16]
load_kernel:
    mov bx, MSG_LOAD_KERNEL
    call print_string
    call print_nl
    mov bx, KERNEL_OFFSET   ; куда читать (ES=0, BX=0x1000)
    mov dh, 31              ; сколько секторов (31*512 = ~15.5 КБ под ядро)
    mov dl, [BOOT_DRIVE]
    call disk_load
    ret

[bits 32]
BEGIN_PM:
    call KERNEL_OFFSET      ; передаём управление ядру (kernel_entry)
    jmp $

BOOT_DRIVE      db 0
MSG_REAL_MODE   db "Started in 16-bit Real Mode", 0
MSG_LOAD_KERNEL db "Loading kernel into memory", 0

times 510-($-$$) db 0
dw 0xaa55

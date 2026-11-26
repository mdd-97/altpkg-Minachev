; Чтение dh секторов с диска dl в ES:BX (BIOS int 0x13, функция 0x02)
disk_load:
    pusha
    push dx
    mov ah, 0x02        ; функция "прочитать секторы"
    mov al, dh          ; сколько секторов
    mov cl, 0x02        ; начиная со 2-го сектора (1-й — это загрузчик)
    mov ch, 0x00        ; цилиндр 0
    mov dh, 0x00        ; головка 0
    int 0x13
    jc disk_error       ; CF=1 -> ошибка
    pop dx
    cmp al, dh          ; BIOS возвращает в al число реально прочитанных
    jne sectors_error
    popa
    ret
disk_error:
    mov bx, DISK_ERROR
    call print_string
    jmp $
sectors_error:
    mov bx, SECTORS_ERROR
    call print_string
    jmp $
DISK_ERROR:    db "Disk read error", 0
SECTORS_ERROR: db "Incorrect number of sectors read", 0

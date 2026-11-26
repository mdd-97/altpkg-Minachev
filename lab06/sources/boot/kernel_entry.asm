[bits 32]
[extern main]
[extern __bss_start]
[extern __bss_end]
global _start
_start:
    cld
    mov edi, __bss_start
    mov ecx, __bss_end
    sub ecx, edi
    xor eax, eax
    rep stosb
    call main
.halt:
    cli
    hlt
    jmp .halt

OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)
SECTIONS {
  . = 0x1000;
  .text : { boot/kernel_entry.o(.text) *(.text*) }
  .rodata ALIGN(16) : { *(.rodata*) }
  .data ALIGN(16) : { *(.data*) }
  .bss ALIGN(16) : { __bss_start = .; *(.bss*) *(COMMON) __bss_end = .; }
  ASSERT(. <= 0x4e00, "kernel memory exceeds 31 sectors")
  /DISCARD/ : { *(.note*) *(.comment*) *(.eh_frame*) }
}

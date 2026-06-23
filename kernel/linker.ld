ENTRY(_start)

SECTIONS
{
    /*
     * LoongArch64 QEMU virt 常用内核虚拟入口。
     * 教学中先使用 QEMU/固件已经建立好的直接映射。
     */
    . = 0x9000000000200000;

    .text : ALIGN(4K) {
        KEEP(*(.text.boot))
        *(.text .text.*)
    }

    .rodata : ALIGN(4K) {
        *(.rodata .rodata.*)
    }

    .data : ALIGN(4K) {
        *(.data .data.*)
    }

    __bss_start = .;
    .bss : ALIGN(4K) {
        *(.bss .bss.*)
        *(COMMON)
    }
    __bss_end = .;
}

/*
 * miniOS 启动入口。
 * week01-00-skeleton：CPU 有入口，但什么都不做，原地打转。
 */

    .section .text.boot, "ax"
    .globl _start

_start:
    b           halt

halt:
    idle        0
    b           halt

    .section .bss.stack, "aw", @nobits
    .align 12
boot_stack:
    .space 4096
boot_stack_top:
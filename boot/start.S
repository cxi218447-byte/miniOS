/*
 * miniOS 启动入口。
 * week01-01-stack-setup：设置好内核栈，但还没有进入 C。
 */

    .section .text.boot, "ax"
    .globl _start

_start:
    /* 设置内核栈。栈从高地址向低地址增长。 */
    la.global   $sp, boot_stack_top

halt:
    idle        0
    b           halt

    .section .bss.stack, "aw", @nobits
    .align 12
boot_stack:
    .space 4096
boot_stack_top:
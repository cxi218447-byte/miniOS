/*
 * miniOS 启动入口。
 * 目标：让学生看到 CPU 进入内核后最先执行的汇编代码。
 */

    .section .text.boot, "ax"
    .globl _start

_start:
    /* 设置内核栈。栈从高地址向低地址增长。 */
    la.global   $sp, boot_stack_top

    /* 清零 .bss，保证未初始化的全局变量从 0 开始。 */
    bl          clear_bss

    /* 进入 C 语言内核主函数。 */
    bl          kernel_main

halt:
    idle        0
    b           halt

clear_bss:
    la.global   $t0, __bss_start
    la.global   $t1, __bss_end

1:
    beq         $t0, $t1, 2f
    st.b        $zero, $t0, 0
    addi.d      $t0, $t0, 1
    b           1b

2:
    jr          $ra

/*
 * 异常入口框架。
 * 第 5 次课实验会把 EENTRY 指向这里，并在 C 代码里打印异常信息。
 */
    .section .text.exception, "ax"
    .globl exception_entry

exception_entry:
    addi.d      $sp, $sp, -32
    st.d        $ra, $sp, 24

    /* ESTAT=0x5，ERA=0x6。这里先把两个 CSR 传给 C 处理函数。 */
    csrrd       $a0, 0x5
    csrrd       $a1, 0x6
    bl          exception_handler

    ld.d        $ra, $sp, 24
    addi.d      $sp, $sp, 32
    ertn

    .section .bss.stack, "aw", @nobits
    .align 12
boot_stack:
    .space 4096
boot_stack_top:

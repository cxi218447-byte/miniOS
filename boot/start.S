/*
 * miniOS 启动入口。
 * 第 1 次课：设栈 → 进入 kernel_main → halt。
 * 第 2 次课：在进入 C 前增加 clear_bss。
 * 第 10 次课：新增 exception_entry，供 exception_init 写入 CSR.EENTRY。
 * 第 11 次课：exception_entry 升级为完整寄存器保存——LoongArch 的同步异常
 *   （break/syscall...）和异步中断（定时器等）共享同一个 EENTRY 入口，
 *   用 ESTAT 的 Ecode 字段区分（Ecode==0 表示中断）。中断可能打在任意一条
 *   指令中间，第10次课只存 $ra 是不够的：C 处理函数一旦用到 $a0-$a7/$t0-$t8，
 *   就会破坏被中断代码里活跃的同名寄存器，因此必须把它们全部主动保存。
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
 * ---- 第 10/11 次课：异常与中断共享入口 ----
 * 硬件在异常或中断发生时直接跳到 CSR.EENTRY 记录的地址（这里），
 * 而不是走 bl/jr $ra 的普通调用路径，所以现场要自己主动保存。
 * 返回用 ertn（把 PC 恢复为 ERA），不是 jr $ra。
 *
 * 栈帧 144 字节（18 个寄存器 × 8 字节，已 16 字节对齐）：
 * 保存 $ra + 全部参数寄存器 $a0-$a7 + 全部临时寄存器 $t0-$t8——
 * 这些都是"调用者不保证跨调用存活"的寄存器（第6次课），中断处理函数
 * 一旦使用就会覆盖它们，而中断可能打断任何正在使用这些寄存器的代码。
 */
    .globl exception_entry
exception_entry:
    addi.d      $sp, $sp, -144
    st.d        $ra, $sp, 0
    st.d        $a0, $sp, 8
    st.d        $a1, $sp, 16
    st.d        $a2, $sp, 24
    st.d        $a3, $sp, 32
    st.d        $a4, $sp, 40
    st.d        $a5, $sp, 48
    st.d        $a6, $sp, 56
    st.d        $a7, $sp, 64
    st.d        $t0, $sp, 72
    st.d        $t1, $sp, 80
    st.d        $t2, $sp, 88
    st.d        $t3, $sp, 96
    st.d        $t4, $sp, 104
    st.d        $t5, $sp, 112
    st.d        $t6, $sp, 120
    st.d        $t7, $sp, 128
    st.d        $t8, $sp, 136

    csrrd       $a0, 0x5            /* ESTAT：异常/中断状态与原因 */
    csrrd       $a1, 0x6            /* ERA：返回地址 */
    bl          exception_handler   /* 返回值 $a0 = 处理函数给出的新 ERA */

    csrwr       $a0, 0x6            /* 写回 ERA：break/syscall 这类精确异常
                                       ERA 指向触发指令本身，不写回会在原地死循环；
                                       中断类 exception_handler 原样返回 era，不受影响 */
    ld.d        $ra, $sp, 0
    ld.d        $a0, $sp, 8
    ld.d        $a1, $sp, 16
    ld.d        $a2, $sp, 24
    ld.d        $a3, $sp, 32
    ld.d        $a4, $sp, 40
    ld.d        $a5, $sp, 48
    ld.d        $a6, $sp, 56
    ld.d        $a7, $sp, 64
    ld.d        $t0, $sp, 72
    ld.d        $t1, $sp, 80
    ld.d        $t2, $sp, 88
    ld.d        $t3, $sp, 96
    ld.d        $t4, $sp, 104
    ld.d        $t5, $sp, 112
    ld.d        $t6, $sp, 120
    ld.d        $t7, $sp, 128
    ld.d        $t8, $sp, 136
    addi.d      $sp, $sp, 144
    ertn                            /* 异常返回：PC <- ERA，而不是 jr $ra */

    .section .bss.stack, "aw", @nobits
    .align 12
boot_stack:
    .space 4096
boot_stack_top:

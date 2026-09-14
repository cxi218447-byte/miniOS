/*
 * 第 6 次课：函数调用约定与栈帧 demo。
 * 对应讲义 §4.2 叶子函数 + §4.3 非叶子函数 + §4.1 callee-saved 规则。
 *
 * 本文件代表指令/结构：
 *   叶子函数    sa_add_one / sa_add：参数在 $a0/$a1，返回值在 $a0，不碰 $ra
 *   非叶子函数  sa_add3：栈帧 addi.d $sp,-N → st.d $ra → 两次 bl → ld.d $ra → jr $ra
 *   非叶子函数  sa_strlen_and_puts：栈帧同上，另外借用 callee-saved 的
 *               $s0/$s1 跨两次 bl（strlen/uart_puts）保存值——入口存、出口取，
 *               和 $ra 的存取是同一套纪律，只是换成了 $s* 寄存器。
 *
 * sa_add3 刻意用两次 bl 调用同一个叶子函数 sa_add，用来暴露一个真实故障：
 * 第一次 bl 会覆盖 $ra；若 sa_add3 不在入口先把自己的 $ra 存进栈帧，
 * 第二次 bl 返回后 jr $ra 就会跳到错误的地方（对照讲义 Task C）。
 */

    .section .text

/* ---- 叶子函数：int sa_add_one(int x) -> x + 1 ---- */
    .globl sa_add_one
sa_add_one:
    addi.d  $a0, $a0, 1
    jr      $ra

/* ---- 叶子函数：int sa_add(int x, int y) -> x + y ---- */
    .globl sa_add
sa_add:
    add.d   $a0, $a0, $a1
    jr      $ra

/* ---- 非叶子函数：int sa_add3(int a, int b, int c) -> a + b + c ----
 * 栈帧 32 字节（保持 16 字节对齐）：
 *   $sp+24  保存调用方传入的 $ra
 *   $sp+16  局部变量槽，暂存 c（跨越第一次 bl 调用）
 */
    .globl sa_add3
sa_add3:
    addi.d  $sp, $sp, -32
    st.d    $ra, $sp, 24       /* 必须先存：下面第一次 bl 会覆盖 $ra */
    st.d    $a2, $sp, 16       /* c 暂存到栈帧局部变量，避免被 sa_add 用到的寄存器覆盖 */

    bl      sa_add             /* a0 = a + b（此时 $ra 已被改写为“回到这里”） */

    ld.d    $a1, $sp, 16       /* y = c：从栈帧局部变量取回 */
    bl      sa_add             /* a0 = (a+b) + c（$ra 再次被改写） */

    ld.d    $ra, $sp, 24       /* 恢复调用方真正的返回地址 */
    addi.d  $sp, $sp, 32
    jr      $ra

/* ---- 非叶子函数：long sa_strlen_and_puts(const char *s) ----
 * 打印 s（调用第 1 次课的 uart_puts），返回 strlen(s)（调用第 2 次课的 strlen）。
 * 栈帧 32 字节（保持 16 字节对齐）：
 *   $sp+24  保存调用方传入的 $ra
 *   $sp+16  保存调用方的 $s0（callee-saved，借用前必存）
 *   $sp+8   保存调用方的 $s1（callee-saved，借用前必存）
 *
 * $s0/$s1 分别跨两次 bl 保存字符串指针 s 与长度 len：strlen/uart_puts
 * 内部可能随意改写 $t*、$a*（caller-saved，不用负责恢复），但不会碰 $s0/$s1，
 * 因为这两个寄存器的"不被改写"是 callee-saved 规则保证的。
 */
    .globl sa_strlen_and_puts
sa_strlen_and_puts:
    addi.d  $sp, $sp, -32
    st.d    $ra, $sp, 24
    st.d    $s0, $sp, 16       /* 借用前先存调用者的 $s0 */
    st.d    $s1, $sp, 8        /* 借用前先存调用者的 $s1 */

    move    $s0, $a0           /* s0 = s，跨越下面两次 bl 保存 */
    bl      strlen              /* a0 = strlen(s)；strlen 是叶子函数，不碰 $ra/$s* */
    move    $s1, $a0           /* s1 = len，跨越下面这次 bl 保存 */

    move    $a0, $s0           /* 取回 s（未被 strlen 改写，因为存在 $s0 里） */
    bl      uart_puts           /* 打印 s；uart_puts 是 C 写的非叶子函数，同样不碰 $s* */

    move    $a0, $s1           /* 返回值 = len（取回未被改写的 $s1） */

    ld.d    $s1, $sp, 8        /* 恢复调用者的 $s1 */
    ld.d    $s0, $sp, 16       /* 恢复调用者的 $s0 */
    ld.d    $ra, $sp, 24       /* 恢复调用方真正的返回地址 */
    addi.d  $sp, $sp, 32
    jr      $ra

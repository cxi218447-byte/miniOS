/*
 * 第 3 次课：按教材《汇编语言编程基础 基于 LoongArch》第 3 章分类，
 * 每类至少 1 条代表性指令（可运行 demo）。
 *
 * 分类 → 本文件代表指令：
 *   算术     add.d / sub.d / mul.d / addi.d（addi 亦见于 start.S）
 *   逻辑     andi
 *   移位     slli.d
 *   条件赋值 slt
 *   位操作   ext.w.b
 * 访存 / 转移 / 杂项 见 boot/start.S（st.b、beq、bl、jr、idle）
 * 第 4 章浮点：本文件不实现（课堂口述 1 条 fadd.s）
 */

    .section .text

/* ---- 算术：add.d + sub.d ---- */
    .globl alu_expr
alu_expr:
    add.d   $t0, $a0, $a1      /* t0 = a + b */
    sub.d   $a0, $t0, $a2      /* a0 = t0 - c */
    jr      $ra

/* ---- 算术：mul.d ---- */
    .globl alu_mul
alu_mul:
    mul.d   $a0, $a0, $a1      /* a0 = a * b */
    jr      $ra

/* ---- 逻辑：andi ---- */
    .globl alu_low8
alu_low8:
    andi    $a0, $a0, 0xff     /* a0 = x & 0xff */
    jr      $ra

/*
 * ---- 移位：slli.d ----
 * 简化：n 以立即数形式给出时用 slli.d；此处 n 在 $a1，用 sll.d。
 * 教材同时有 slli.*（立即数）与 sll.*（寄存器）。
 * 课堂主讲 slli.d；本函数用 sll.d 以便参数化 n。
 * 另提供 alu_slli1：固定 <<1 的 slli.d 纯立即数版。
 */
    .globl alu_slli
alu_slli:
    sll.d   $a0, $a0, $a1      /* a0 = x << (a1 低 6 位) */
    jr      $ra

    .globl alu_slli1
alu_slli1:
    slli.d  $a0, $a0, 1        /* a0 = x << 1 —— 立即数移位代表 */
    jr      $ra

/* ---- 条件赋值：slt ---- */
    .globl alu_slt
alu_slt:
    slt     $a0, $a0, $a1      /* a0 = (a < b) ? 1 : 0 */
    jr      $ra

/* ---- 位操作：ext.w.b ---- */
    .globl alu_extb
alu_extb:
    ext.w.b $a0, $a0           /* 低 8 位符号扩展 */
    jr      $ra

/* ---- 算术+临时格：两次 add 表达 ×2（对照 slli） ---- */
    .globl alu_sum2
alu_sum2:
    add.d   $t0, $a0, $a1
    add.d   $a0, $t0, $t0
    jr      $ra

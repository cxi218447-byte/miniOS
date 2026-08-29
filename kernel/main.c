/*
 * 内核 C 入口。
 * 第 1 次课：Hello；第 2 次课：.data/.bss；
 * 第 3 次课：按教材第 3 章每类指令至少 1 条的验收输出。
 */

#include "printk.h"
#include "string.h"
#include "regs_alu.h"

static char bss_buffer[16];
static char data_message[] = "data section ok";

static void print_u64_dec(unsigned long v)
{
    char buf[24];
    int i = 0;
    int j;

    if (v == 0) {
        printk("0");
        return;
    }

    while (v > 0) {
        buf[i++] = (char)('0' + (v % 10));
        v /= 10;
    }
    for (j = i - 1; j >= 0; j--) {
        char s[2];
        s[0] = buf[j];
        s[1] = '\0';
        printk(s);
    }
}

static void print_u64_hex(unsigned long v)
{
    const char *digits = "0123456789abcdef";
    char buf[20];
    int i = 0;
    int j;

    if (v == 0) {
        printk("0");
        return;
    }

    while (v > 0) {
        buf[i++] = digits[v & 0xf];
        v >>= 4;
    }
    for (j = i - 1; j >= 0; j--) {
        char s[2];
        s[0] = buf[j];
        s[1] = '\0';
        printk(s);
    }
}

static void print_i64_dec(long v)
{
    if (v < 0) {
        printk("-");
        print_u64_dec((unsigned long)(-v));
    } else {
        print_u64_dec((unsigned long)v);
    }
}

void kernel_main(void)
{
    char buf[32];
    const char *msg = "Hello miniOS on LoongArch64\n";
    long r;

    printk(msg);

    memset(buf, 0, sizeof(buf));
    memcpy(buf, data_message, strlen(data_message));
    printk(buf);
    printk("\n");

    if (bss_buffer[0] == 0) {
        printk("bss section cleared\n");
    }

    /* ---- 第 3 次课：指令分类验收（每类 ≥1 条） ---- */

    /* 算术 add/sub */
    r = alu_expr(3, 5, 2);
    printk("arith add/sub: (3+5)-2 = ");
    print_i64_dec(r);
    printk("\n");

    /* 算术 mul */
    r = alu_mul(6, 7);
    printk("arith mul: 6*7 = ");
    print_i64_dec(r);
    printk("\n");

    /* 逻辑 andi */
    r = alu_low8(0x1234);
    printk("logic andi: 0x1234 & 0xff = 0x");
    print_u64_hex((unsigned long)r);
    printk("\n");

    /* 移位 slli.d 立即数 */
    r = alu_slli1(5);
    printk("shift slli: 5<<1 = ");
    print_i64_dec(r);
    printk("\n");

    /* 条件赋值 slt */
    r = alu_slt(3, 5);
    printk("cond slt: (3<5) = ");
    print_i64_dec(r);
    printk("\n");

    /* 位操作 ext.w.b：0x7f 正数字节 */
    r = alu_extb(0x7f);
    printk("bit ext.w.b: 0x7f -> ");
    print_i64_dec(r);
    printk("\n");

    /* 临时寄存器 + 两次 add（对照移位） */
    r = alu_sum2(7, 1);
    printk("arith temp: (7+1)+(7+1) = ");
    print_i64_dec(r);
    printk("\n");

    /*
     * 访存 st.b：见 clear_bss（上方 bss section cleared）
     * 转移 bl/jr/beq：见 boot/start.S
     * 杂项 idle：本函数末尾
     * 浮点：第 4 章，本课不运行
     */
    printk("mem st.b: see clear_bss\n");
    printk("branch: see bl/jr/beq in start.S\n");
    printk("misc idle: halt loop below\n");
    printk("float: textbook ch4, not run here\n");

    printk("week03-regs-alu check done\n");

    while (1) {
        __asm__ volatile("idle 0");
    }
}

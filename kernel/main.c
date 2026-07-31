/*
 * 内核 C 入口。
 * 第 1 次课：Hello 输出；第 2 次课：验证 .data 可读、.bss 已清零。
 */

#include "printk.h"
#include "string.h"

/* 未显式初始化 → 落在 .bss，依赖 boot/start.S 的 clear_bss 清零。 */
static char bss_buffer[16];
/* 有初始值 → 落在 .data，镜像里带着字符串内容。 */
static char data_message[] = "data section ok";

void kernel_main(void)
{
    char buf[32];
    const char *msg = "Hello miniOS on LoongArch64\n";

    printk(msg);                                     /* ① 第 1 次课 Hello 链路 */

    memset(buf, 0, sizeof(buf));                     /* ② 清零局部 buf */
    memcpy(buf, data_message, strlen(data_message)); /* ③ 从 .data 复制到栈 */
    printk(buf);                                     /* ④ 打印 data section ok */
    printk("\n");

    if (bss_buffer[0] == 0) {                        /* ⑤ 检查 .bss 是否已清零 */
        printk("bss section cleared\n");
    }

    printk("week1-week2 check done\n");              /* ⑥ 阶段标记 */

    while (1) {
        __asm__ volatile("idle 0");                  /* ⑦ 停机 */
    }
}

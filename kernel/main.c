#include "printk.h"
#include "string.h"

static char bss_buffer[16];
static char data_message[] = "data section ok";

void kernel_main(void)
{
    char buf[32];
    const char *msg = "Hello miniOS on LoongArch64\n";

    printk(msg);

    memset(buf, 0, sizeof(buf));
    memcpy(buf, data_message, strlen(data_message));
    printk(buf);
    printk("\n");

    if (bss_buffer[0] == 0) {
        printk("bss section cleared\n");
    }

    printk("week1-week2 check done\n");

    while (1) {
        __asm__ volatile("idle 0");
    }
}

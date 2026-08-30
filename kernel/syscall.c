/*
 * 第 9 次课：最小系统调用实现——把"内核自己 printk"
 * 包装成编号化的内核服务接口 sys_write，并给出分发器。
 *
 * printk(s) 与 sys_write(1, s, strlen(s)) 是同一条底层路径
 * （见 uart_putc），sys_write 只是缩小了接口面并加上参数校验。
 */
#include "syscall.h"
#include "uart.h"

long sys_write(int fd, const char *buf, size_t len)
{
    size_t i;

    if (fd != 1 && fd != 2)
        return -1;

    for (i = 0; i < len; i++) {
        if (buf[i] == '\n')
            uart_putc('\r');
        uart_putc(buf[i]);
    }
    return (long)len;
}

long syscall_dispatch(long nr, long a0, long a1, long a2)
{
    if (nr == SYS_WRITE)
        return sys_write((int)a0, (const char *)a1, (size_t)a2);
    return -1;
}

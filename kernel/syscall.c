#include "syscall.h"
#include "uart.h"

long sys_write(int fd, const char *buf, size_t len)
{
    if (fd != 1 && fd != 2) {
        return -1;
    }

    for (size_t i = 0; i < len; i++) {
        if (buf[i] == '\n') {
            uart_putc('\r');
        }
        uart_putc(buf[i]);
    }

    return (long)len;
}

long syscall_dispatch(long nr, long a0, long a1, long a2)
{
    if (nr == SYS_WRITE) {
        return sys_write((int)a0, (const char *)a1, (size_t)a2);
    }

    return -1;
}

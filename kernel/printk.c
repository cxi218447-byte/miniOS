#include "printk.h"
#include "uart.h"

void uart_putc(char ch)
{
    volatile unsigned char *uart = (volatile unsigned char *)UART0_BASE;

    /* 裸机早期先不轮询状态寄存器，直接写发送寄存器，便于跑通。 */
    *uart = (unsigned char)ch;
}

void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

void printk(const char *s)
{
    uart_puts(s);
}

void printk_hex(unsigned long v)
{
    const char *digits = "0123456789abcdef";
    char buf[16];
    int i = 0;
    int j;

    if (v == 0) {
        uart_putc('0');
        return;
    }

    while (v > 0) {
        buf[i++] = digits[v & 0xf];
        v >>= 4;
    }
    for (j = i - 1; j >= 0; j--) {
        uart_putc(buf[j]);
    }
}

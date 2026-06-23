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

void printk_hex(unsigned long value)
{
    static const char digits[] = "0123456789abcdef";

    printk("0x");
    for (int i = 60; i >= 0; i -= 4) {
        uart_putc(digits[(value >> i) & 0xf]);
    }
}

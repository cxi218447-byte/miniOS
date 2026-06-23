#ifndef MINIOS_UART_H
#define MINIOS_UART_H

#include "types.h"

/*
 * QEMU loongarch64 virt/龙芯平台常见 16550 串口地址。
 * 使用高半区直接映射地址，便于内核直接访问 MMIO。
 */
#define UART0_BASE 0x900000001fe001e0UL

void uart_putc(char ch);
void uart_puts(const char *s);

#endif

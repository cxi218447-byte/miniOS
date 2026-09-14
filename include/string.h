#ifndef MINIOS_STRING_H
#define MINIOS_STRING_H

#include "types.h"

void *memset(void *dst, int value, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
size_t strlen(const char *s);

/* memmove：区间重叠时 memcpy 处理不了，这个能。
 * strcmp：逐字节比较，返回差值。
 * zero_and_copy：组合 memset+strlen+memcpy，安全地把字符串放进固定缓冲区。
 * 实现见 lib/string.S。 */
void *memmove(void *dst, const void *src, size_t n);
int strcmp(const char *a, const char *b);
void *zero_and_copy(void *dst, const char *src, size_t dst_size);

#endif

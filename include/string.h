#ifndef MINIOS_STRING_H
#define MINIOS_STRING_H

#include "types.h"

void *memset(void *dst, int value, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
size_t strlen(const char *s);

#endif

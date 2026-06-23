#ifndef MINIOS_SYSCALL_H
#define MINIOS_SYSCALL_H

#include "types.h"

#define SYS_WRITE 64

long sys_write(int fd, const char *buf, size_t len);
long syscall_dispatch(long nr, long a0, long a1, long a2);

#endif

/*
 * 第 9 次课：最小系统调用接口声明。
 * 实现见 kernel/syscall.c。
 */
#ifndef MINIOS_SYSCALL_H
#define MINIOS_SYSCALL_H

#include "types.h"

/* 系统调用号（教学最小集，仅 write） */
#define SYS_WRITE 1

/* sys_write(fd, buf, len)：只允许 fd=1(stdout)/2(stderr)，其余返回 -1。
 * 成功返回写入长度，与普通函数一样走 $a0-$a2/$a0，但语义上代表"内核服务"。
 */
long sys_write(int fd, const char *buf, size_t len);

/* 系统调用分发器：nr 决定调用哪个服务，参数固定占用 a0-a2 三个槽位。
 * 未知 nr 返回 -1，便于后续扩展而不破坏已有调用点。
 */
long syscall_dispatch(long nr, long a0, long a1, long a2);

#endif

# 第 8 次课教师讲义：UART 驱动、输出子系统与系统调用 sys_write

> 技术编号：`08`　|　建议检查点：`08-uart-syscall`  
> 合并原第 10 次课（UART 驱动与输出子系统）+ 原第 11 次课（系统调用 sys_write）。

## 0. 一句话目标

把“能打印”整理成分层的输出子系统，再把它包进一个编号化的最小系统调用 `sys_write`，理解“内核服务接口”与“普通函数调用”的差异。

## 1. 课程定位（Why）

第 1 次课靠“直接写地址”把 Hello 打出来；这条路径现在要做两件事：

```text
整理成子系统：基址/init 收拢、volatile MMIO、轮询发送
          ↓
包装成服务：编号化入口 sys_write(fd, buf, len)，而不是到处直接碰硬件
```

这也是第 12 次课板级迁移与综合展示前，内核服务边界的最后一次系统化整理。

## 2. 教学目标

1. 画出 `printk → uart_puts → uart_putc → MMIO` 调用图，解释 `UART0_BASE` 与 `volatile`。
2. 说明 16550 风格 THR/LSR 轮询发送的教学角色，提出 `platform`/`uart` 分层草案。
3. 说明 syscall 与 `bl` 普通调用的差异（入口、接口稳定性——教学版）。
4. 读懂 `sys_write(fd, buf, len)` 与 `syscall_dispatch` 的分发逻辑。
5. 理解 `printk(s) ≈ sys_write(1, s, strlen(s))` 的封装关系。

## 3. 课前准备

- `kernel/printk.c`、`include/uart.h`
- `kernel/syscall.c`、`include/syscall.h`
- 复习第 4 次课 MMIO = store、第 6 次课调用约定

## 4. 课程知识

### 4.1 当前输出路径

```text
printk(s)
  → uart_puts(s)
      → 遇 \n 先发 \r
      → uart_putc(*s++)
          → *(volatile u8*)UART0_BASE = ch
```

```c
void uart_putc(char ch)
{
    volatile unsigned char *uart = (volatile unsigned char *)UART0_BASE;
    *uart = (unsigned char)ch;
}
```

1. **固定地址写**：设备寄存器映射在地址空间。
2. **volatile**：每次必须真实访问，防止编译器优化掉。
3. **教学取舍**：早期不查 LSR，优先跑通；轮询发送留到 §4.2。

### 4.2 汇编视角：MMIO 写与轮询发送

```asm
# 直接写：$a0 = ch, $t0 = uart base
    st.b    $a0, $t0, 0
    jr      $ra
```

```asm
# 轮询发送（示意，板级更重要）：读状态 → 掩码 → 空则写数据
wait_tx:
    ld.bu   $t1, $t0, LSR_OFF
    andi    $t1, $t1, TX_EMPTY_MASK
    beqz    $t1, wait_tx
    st.b    $a0, $t0, THR_OFF
    jr      $ra
```

综合第 3/4/5 次课：逻辑（`andi`）、访存（`ld.bu`/`st.b`）、循环（`beqz`/回跳）。

### 4.3 设备抽象建议（讨论用，不要求本课实现）

```c
struct uart_device {
    unsigned long base;
    void (*putc)(struct uart_device *dev, char c);
};
```

平台相关（base、init、寄存器偏移）与平台无关（`printk` 逻辑、字符串遍历）分层，为板级迁移做准备。

### 4.4 sys_write 精读

```c
long sys_write(int fd, const char *buf, size_t len)
{
    if (fd != 1 && fd != 2)
        return -1;
    for (size_t i = 0; i < len; i++) {
        if (buf[i] == '\n')
            uart_putc('\r');
        uart_putc(buf[i]);
    }
    return (long)len;
}
```

1. **缩小接口面**：只允许 stdout/stderr。
2. **复用** `uart_putc`：边界在接口，不重复造轮子——`sys_write` 是 §4.1 输出路径之上的一层薄封装。
3. **返回长度**，失败 -1。

### 4.5 分发器与参数约定

```c
long syscall_dispatch(long nr, long a0, long a1, long a2)
{
    if (nr == SYS_WRITE)
        return sys_write((int)a0, (const char *)a1, (size_t)a2);
    return -1;
}
```

| 含义 | 教学放置 |
|---|---|
| 系统调用号 | `$a7` 或课程约定寄存器 |
| 参数 | `$a0`–`$a2` |
| 返回值 | `$a0` |

用户侧参数布置（示意，具体陷入指令按课堂方案选择）：

```asm
    li.d      $a0, 1              # fd = 1
    la.global $a1, msg
    li.d      $a2, 13             # len
    # li.d $a7, SYS_WRITE
    # syscall  或  bl 到内核封装
```

教学阶段可先**内核内直接调用 dispatch** 降低难度；关键是稳定编号与参数槽位，而不是一次上完整用户态隔离。

## 5. 课堂 Demo

1. 把 UART 基址改错 → 无输出 → 改回，体会“基址散落”的风险。
2. 展示 CRLF 处理（`\n` 先发 `\r`）。
3. 从 `printk` 走到 `uart_putc`，再走 `sys_write` 路径，演示非法 `fd` 返回 -1。
4. 对照参数表填空：`nr`/`$a0`–`$a2`/返回值分别放在哪。
5. 可运行 demo：`kernel/syscall.c`（`sys_write`/`syscall_dispatch`），`kernel/main.c` 已验收合法 fd=1、非法 fd=99、未知系统调用号三种情况，`make run` 核对 `week08-uart-syscall check done`。

## 6. 实验实践

**Task A**　画出 `printk → sys_write → uart_putc → MMIO` 的完整调用图。

**Task B**　文档化本课寄存器约定（nr、参数、返回值、错误码，一页纸）。

**Task C**　构造对 `SYS_WRITE` 的测试输出：验证合法 fd 与非法 fd 的返回行为。

**Task D（选做）**　实现等待 LSR 的 `uart_putc_robust`，或给 `sys_write` 增加一个简单 C 包装。

## 7. AI 共学

允许查 16550 寄存器表、对比 Linux write 语义；地址与行为必须以本课程代码/手册为准，不得凭空编造。

## 8. 思考与拓展

1. 多上下文同时 `printk` 的风险？
2. 轮询驱动与中断驱动的位置？
3. 为什么要统一入口而不是给每个服务一个裸函数地址？
4. 后续加入更多 syscall 时分发结构如何扩展？

## 9. 板书

```text
printk → puts → putc → st.b MMIO（volatile 防优化）
nr + args → dispatch → sys_write → uart
printk 是 sys_write 的便民封装；接口稳定 > 直接碰硬件
```

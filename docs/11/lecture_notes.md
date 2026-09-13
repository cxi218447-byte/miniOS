# 第 11 次课教师讲义：中断/定时器实验 + miniOS 内核服务整理

> 技术编号：`11`　|　建议检查点：`11-irq-kernel-recap`　|　4 学时连排（纯实验课，不引入新理论）  
> 理论已在第 10 次课收官；本课上机验证定时器中断，并把第 1–10 次课的内核服务边界系统整理一遍。

## 0. 一句话目标

写出能真正周期性触发的定时器中断，观察它与第 9 次课异常入口共享同一硬件机制；再把 miniOS 目前的内核服务（启动/输出/库函数/系统调用/异常/中断）画成一张地图。

## 1. 课程定位（Why）

```text
第 9 次课：讲透同步异常（exception_entry 最小骨架，break 触发验证）
     ↓
第 11 次课单元一：中断是异常的"异步版本"——同一个 EENTRY 入口，
                 用 ESTAT.Ecode==0 区分，上机把定时器接起来
     ↓
第 11 次课单元二：退一步看全局——miniOS 现在有哪些内核服务？
                 边界在哪？谁调用谁？
```

本课 4 学时连排，不引入新理论，是第 12 次课板级迁移与综合展示前的最后一次巩固。

## 2. 教学目标

**单元一（定时器中断，第 1–2 学时）**

1. 说清定时器三个 CSR 的分工：`TCFG`（配置+使能）、`TVAL`（只读倒数值）、`TICLR`（清源）。
2. 说清两层使能：`ECFG.LIE`（分源开关）+ `CRMD.IE`（总开关）。
3. 理解异常与中断**共享同一个 EENTRY 入口**，用 `ESTAT.Ecode==0` 区分中断类。
4. 解释为什么中断入口要比第 9 次课的 `exception_entry` 保存更多寄存器。
5. 跑通一个真实的周期性定时器中断 demo，能读懂 tick 计数输出。
6. **亲手写代码**实现 `timer_read_remaining()`（读 TVAL）与变速 tick，验证"周期模式自动重装"不是只停留在口头理解上。

**单元二（内核服务整理，第 3–4 学时）**

7. 画出 miniOS 当前的内核服务地图（启动→输出→库函数→系统调用→异常/中断）。
8. 能说明每个模块的输入/输出边界，以及"谁能直接碰硬件、谁只能调用接口"。
9. **亲手写一个 `kernel_integration_demo()`**，把服务地图从"画出来的图"变成"真正跑起来的集成代码"，体会操作系统本质是服务集成+事件驱动模拟。
10. 为第 12 次课的板级迁移与综合展示准备一份可复用的架构图素材与代码起点。

## 3. 课前准备

- 复习第 9 次课 `boot/start.S` 的 `exception_entry`、`kernel/exception.c`
- 打开 `kernel/irq.c`、`include/irq.h`
- 复习第 6 次课"caller-saved 寄存器"概念

## 4. 单元一：定时器中断（第 1–2 学时）

### 4.1 定时器三个 CSR

| CSR | 编号 | 读/写 | 作用 |
|---|---|---|---|
| `TCFG` | `0x41` | 写 | bit0=En 使能，bit1=Periodic 周期模式，高位=InitVal 初值 |
| `TVAL` | `0x42` | 读 | 当前倒数值（Task3.5 要求学生自己写 `csrrd` 读出来，验证周期模式自动重装） |
| `TICLR` | `0x44` | 写 1 | 清除定时器中断挂起标志，**不清会立刻反复重入** |

```c
void timer_init(unsigned long count)
{
    unsigned long tcfg = (count << 2) | TCFG_EN | TCFG_PERIODIC;
    __asm__ volatile("csrwr %0, 0x41" : "+r"(tcfg) : : "memory");
    ecfg_enable_timer_line();
    crmd_enable_ie();
}
```

`count << 2`：`TCFG` 的 InitVal 字段从 bit2 开始，低两位留给 En/Periodic 标志位。

### 4.2 两层使能

| 开关 | CSR/位 | 教学类比 |
|---|---|---|
| 分源开关 | `ECFG`（`0x4`）bit11 | 这一条中断线允不允许响 |
| 总开关 | `CRMD`（`0x0`）bit2（IE） | CPU 整体允不允许响应任何中断 |

两者都要开，定时器中断才能真正送达 CPU。用 `csrxchg`（读改写、按掩码只改指定位）而不是整体 `csrwr`，避免破坏其他无关位：

```c
static inline void ecfg_enable_timer_line(void)
{
    unsigned long mask = 1UL << 11;
    unsigned long val  = 1UL << 11;
    __asm__ volatile("csrxchg %0, %1, 0x4" : "+r"(val) : "r"(mask) : "memory");
}
```

`csrxchg rd, rj, csr`：`csr = (csr & ~rj) | (rd & rj)`，`rd` 同时带回旧值。

### 4.3 异常与中断共享入口

LoongArch 里，同步异常（`break`/`syscall`...）和异步中断（定时器等）走**同一个** `CSR.EENTRY`，硬件不区分。区分靠软件读 `ESTAT.Ecode`（bit[21:16]）：

```c
unsigned long ecode = (estat >> 16) & 0x3f;
if (ecode == 0) {
    irq_dispatch(estat);   /* 中断类：ERA 已是正确续跑点，原样返回 */
    return era;
}
/* 否则是同步异常，走第9次课的 era+4 逻辑 */
```

定时器中断在 `ESTAT` 的 IS 位段固定占**第 11 位**（与 `ECFG` 的分源开关是同一位号）。

### 4.4 为什么中断入口要保存更多寄存器

第 9 次课的 `exception_entry` 只存 `$ra`，够用是因为 `break` 是**软件主动**触发的——写这段代码的人知道即将发生什么。

中断不同：它可能打断**任何**正在执行的代码，包括正在用 `$a0`-`$a7`、`$t0`-`$t8` 存活跃数据的代码。`exception_handler` 一旦调用（哪怕只是 `printk`），这些寄存器就会被覆盖。所以第 11 次课把 `exception_entry` 升级成保存 18 个寄存器（`$ra` + `$a0`-`$a7` + `$t0`-`$t8`，144 字节栈帧）：

```asm
exception_entry:
    addi.d  $sp, $sp, -144
    st.d    $ra, $sp, 0
    st.d    $a0, $sp, 8
    ...
    st.d    $t8, $sp, 136
    csrrd   $a0, 0x5
    csrrd   $a1, 0x6
    bl      exception_handler
    csrwr   $a0, 0x6
    ld.d    $ra, $sp, 0
    ...
    ld.d    $t8, $sp, 136
    addi.d  $sp, $sp, 144
    ertn
```

这不是"中断专属的新入口"，而是把第 9 次课的入口**原地升级**——因为硬件本来就共享一个 EENTRY。

### 4.5 实测数据（供课堂对照）

```text
timer_init: periodic timer interrupt enabled
tick #1
tick #2
tick #3
tick #4
tick #5
collected 5 timer ticks via interrupt, timer_stop() called
```

`TIMER_COUNT = 0x1000000` 在 QEMU virt 上实测约每秒 1–2 次 tick（与宿主机模拟速度有关，不代表真实物理时间单位）；调大 `TIMER_COUNT` tick 变慢，调小变快。

## 5. 单元二：miniOS 内核服务整理（第 3–4 学时）

### 5.1 服务地图（课堂共画）

```text
boot/start.S _start
  ├─ clear_bss                         第2次课
  ├─ kernel_main                       第1次课
  │    ├─ printk → uart_puts → uart_putc     第1/8次课（直接碰硬件：MMIO）
  │    ├─ regs_alu / mem_fp / branch_loop / stack_abi  第3-6次课（纯计算，无外部依赖）
  │    ├─ memset/memcpy/strlen                第2/7次课（被几乎所有模块依赖）
  │    ├─ syscall_dispatch → sys_write        第8次课（接口收窄，内部仍调用 uart_putc）
  │    └─ exception_init                      第9次课（写 CSR.EENTRY）
  └─ exception_entry（硬件触发，不是 kernel_main 调用）
       ├─ Ecode!=0 → exception_handler        第9次课：同步异常
       └─ Ecode==0 → irq_dispatch → timer_*   第11次课：定时器中断
```

### 5.2 边界讨论

| 问题 | 答案要点 |
|---|---|
| 谁能直接碰硬件（MMIO/CSR）？ | `uart_putc`、`irq.c` 的 CSR 操作、`exception_entry`；其余模块都通过接口调用 |
| 哪个模块被依赖最多？ | `string.S`（`memset`/`memcpy`/`strlen`），几乎每个后续模块都用它 |
| 哪两个模块表面不同、底层同构？ | `printk` 与 `sys_write`——都是 `uart_putc` 的封装，只是接口面不同 |
| 哪个入口不是被 C 代码"调用"，而是硬件跳转？ | `exception_entry`（连接 `_start`/`clear_bss`/`kernel_main` 的普通调用链之外） |

### 5.3 为第 12 次课准备

第 12 次课"综合展示 选题A"直接复用本课整理出的服务地图和 §5.4 写好的 `kernel_integration_demo()`；选题B（板级迁移）要重点标出"哪些是平台相关（UART基址/CSR配置细节因芯片而异）"、"哪些是平台无关（服务分层、调用约定、异常机制模式）"。

### 5.4 集成模拟：从"画地图"到"跑代码"

单纯画服务地图、回答边界问答，容易停留在"我知道各模块是什么"，却没有亲手体会"操作系统就是把这些服务模块串起来、靠事件驱动往前推进"这件事。所以本单元要求学生写一个 `kernel_integration_demo()`，在同一次运行里真正依次调用：库函数（`memset`/`memcpy`/`strlen`）→系统调用（`syscall_dispatch`）→同步异常（`break`）→异步中断（复用单元一的定时器），最后打印集成验收串。

这个函数本身就是"迷你操作系统全流程"的一次真实模拟：启动把它调起来，中间既有主动调用（库函数/系统调用/异常都是当前指令流主动触发），也有被动响应（中断由硬件异步打断、软件自动接住），学生写完这一遍，比看十遍服务地图更能建立"OS 是集成起来的服务 + 事件驱动"的直觉。详见 `lab.md` Task6。

## 6. 课堂 Demo

1. `make run`：完整跑一遍第 1–11 次课累积输出，重点看 `week11-irq-kernel-recap check done` 前后。
2. 现场改小/改大 `TIMER_COUNT`，重新 `make run`，对比 tick 节奏变化。
3. （踩坑复现，选做）临时删掉 `timer_irq_clear()` 调用，观察不清中断源会发生什么。
4. 共画服务地图（§5.1），学生上台补充连线。
5. 教师现场写一遍 `timer_read_remaining()`（Task D）并 `make run`，让学生看到 TVAL 被重新装载，再放手让学生自己实现。
6. 教师现场跑一遍写好的 `kernel_integration_demo()`（Task G），对照 §5.4 逐段讲解"这一步对应哪个服务、主动调用还是被动响应"，再放手让学生照着骨架自己实现。

## 7. 实验实践

**Task A**　跑通 `make run`，核对 5 个 tick 与 `week11-irq-kernel-recap check done`。

**Task B**　修改 `TIMER_COUNT`，记录至少两组不同取值下的实测 tick 间隔（粗略计时即可）。

**Task C**　书面回答：为什么 `irq_dispatch` 路径里 `exception_handler` 返回 `era` 而不是 `era+4`？对照第 9 次课的 `break` 路径说明差异原因。

**Task D（必做，写代码）**　实现 `timer_read_remaining()`（读 TVAL），在 `irq_dispatch` 里打印出来，验证周期模式自动重装（对应 lab.md Task3.5）。

**Task E（必做，写代码）**　实现变速 tick：`irq_ticks()==2` 时重新调用 `timer_init()` 换一个更小的 `TIMER_COUNT`（对应 lab.md Task3.6）。

**Task F**　画出 §5.1 的服务地图，并回答 §5.2 的四个问题。

**Task G（必做，写代码）**　实现 `kernel_integration_demo()`，把库函数/系统调用/异常/中断真正串联跑通一遍（对应 lab.md Task6，见 §5.4）。

**Task H（选做）**　按 §6.3 复现"不清中断源"的故障，记录现象并解释原因（对应 lab.md Task8）。

## 8. AI 共学

允许协助核对 CSR 位定义、整理服务地图、排查 `kernel_integration_demo()` 的编译报错；`TIMER_COUNT` 调参、TVAL 读数、变速 tick、集成 demo 与故障复现的真实输出必须来自本机 `make run`，不得编造。

## 9. 思考与拓展

1. 若一个中断处理函数执行时间过长，会挡住其他更紧急的中断，如何权衡？
2. `irq_dispatch` 目前只认识定时器，如果要接入 UART 接收中断，接口应该怎么扩展？
3. 服务地图里，哪个模块最适合作为板级迁移时"只改这一层"的边界？

## 10. 板书

```text
定时器三件套：TCFG(配置+使能) / TVAL(倒数值) / TICLR(清源)
两层开关：ECFG(分源) + CRMD.IE(总开关)
共享入口：Ecode==0 → 中断(era不变) / Ecode!=0 → 异常(era+4)
中断入口更重：可能打断任何代码，必须存全部 caller-saved 寄存器
服务地图：boot → 输出/库/syscall/异常中断，边界在"谁碰硬件"
kernel_integration_demo：库函数→系统调用→同步异常→异步中断，一次真跑通 = OS集成+事件驱动
```

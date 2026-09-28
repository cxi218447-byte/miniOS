# 第 11 次课教师讲义：库函数复习 + 中断/定时器实验 + miniOS 内核服务整理

> 技术编号：`11`　|　建议检查点：`11-irq-kernel-recap`　|　4 学时连排（纯实验课，不引入新理论）  
> 理论已在第 9 次课收官；本课上机复习库函数、验证定时器中断，并把第 1–9 次课的内核服务边界系统整理一遍。

## 0. 一句话目标

三件事在同一次 4 学时连排里做完：复习并独立扩展一个库函数（巩固第 6/7 次课的寄存器/调用约定/循环设计能力）；写出能真正周期性触发的定时器中断，观察它与第 9 次课异常入口共享同一硬件机制；再把 miniOS 目前的内核服务（启动/输出/库函数/系统调用/异常/中断）跟着指引串成一次真实可跑的集成 demo。

## 1. 课程定位（Why）

```text
第 6/7 次课：学过调用约定、memset/memcpy/strlen/memmove/strcmp/zero_and_copy 的汇编实现
     ↓
第 11 次课单元一：复习这些函数怎么读、怎么用，再独立实现一个新的（strncmp）——
                 检验"能不能不看提示，自己把寄存器/访存/循环/调用约定组合起来"
     ↓
第 9 次课：讲透同步异常（exception_entry 最小骨架，break 触发验证）
     ↓
第 11 次课单元二：中断是异常的"异步版本"——同一个 EENTRY 入口，
                 用 ESTAT.Ecode==0 区分，上机把定时器接起来
     ↓
第 11 次课单元三：退一步看全局——miniOS 现在有哪些内核服务？
                 边界在哪？跟着指引把它们真正串成一次集成 demo 跑通
```

本课 4 学时连排，不引入新理论，是第 12 次课板级迁移与综合展示前的最后一次巩固。单元一虽然涉及库函数，但函数本身（`memset`/`memcpy`/`strlen`/`memmove`/`strcmp`/`zero_and_copy`）从代码 tag `07-libc-asm` 起就已经在仓库里，不是新知识——本课只是**复习+独立扩展**，不重新讲一遍。

## 2. 教学目标

**单元一（库函数复习与独立实现，第 1 学时）**

1. 能读懂 `memset`/`memcpy`/`strlen` 三个基础函数：一种循环骨架，叶子函数。
2. 能读懂两个更复杂的例子：`memmove`（为什么要先判断搬运方向）、`zero_and_copy`（组合调用三个函数，`$s0`/`$s1`/`$ra` 跨 `bl` 保活）。
3. **独立实现 `strncmp`**（`strcmp` 的"最多比较 n 个字符"版本）：不给任何代码，自己写循环、自己处理边界，检验能否独立把前面学过的知识组合成一个新函数。

**单元二（定时器中断，第 2–3 学时）**

4. 说清定时器三个 CSR 的分工：`TCFG`（配置+使能）、`TVAL`（只读倒数值）、`TICLR`（清源）。
5. 说清两层使能：`ECFG.LIE`（分源开关）+ `CRMD.IE`（总开关）。
6. 理解异常与中断**共享同一个 EENTRY 入口**，用 `ESTAT.Ecode==0` 区分中断类。
7. 解释为什么中断入口要比第 9 次课的 `exception_entry` 保存更多寄存器。
8. 跑通一个真实的周期性定时器中断 demo，能读懂 tick 计数输出。
9. **亲手写代码**实现 `timer_read_remaining()`（读 TVAL）、三档变速 tick、`timer_pause()`/`timer_resume()`，验证"周期模式自动重装"与"暂停不等于停止"不是只停留在口头理解上。

**单元三（内核服务整理 + 集成demo，第 4 学时，跟做教程）**

10. 看懂 miniOS 当前的内核服务地图（启动→输出→库函数→系统调用→异常/中断），不要求独立画图。
11. 跟着指引把 `kernel_integration_demo()` 抄进 `kernel/main.c`，`make run` 跑通、截图即完成——体会操作系统本质是服务集成+事件驱动模拟，重点在"亲手跑通"而不是"独立设计"。
12. 为第 12 次课的板级迁移与综合展示准备一份可复用的架构图素材与代码起点。

## 3. 课前准备

- 打开 `include/string.h`、`lib/string.S`（单元一）
- 复习第 9 次课 `boot/start.S` 的 `exception_entry`、`kernel/exception.c`（单元二）
- 打开 `kernel/irq.c`、`include/irq.h`（单元二）
- 复习第 6 次课"caller-saved 寄存器"概念（单元二）

## 4. 单元一：库函数复习与独立实现（第 1 学时）

### 4.1 参数约定复习

| 函数 | `$a0` | `$a1` | `$a2` | 返回 |
|---|---|---|---|---|
| `memset` | dst | byte | n | 原 dst |
| `memcpy` | dst | src | n | 原 dst |
| `strlen` | s | — | — | 长度 |
| `strcmp` | a | b | — | 0/差值 |

三个/四个函数参数个数不同，套用的是同一套调用约定：前几个整数/指针参数走 `$a0`-`$a2`，返回值在 `$a0`。

### 4.2 memset / memcpy / strlen：一种循环骨架，叶子函数

```asm
memset:
    move        $t0, $a0
    beqz        $a2, 2f
1:
    st.b        $a1, $a0, 0
    addi.d      $a0, $a0, 1
    addi.d      $a2, $a2, -1
    bnez        $a2, 1b
2:
    move        $a0, $t0
    jr          $ra
```

`$t0` 先保存原始 `dst`，因为 `$a0` 接下来要当游标用，返回前得把它换回来。`n==0` 时 `beqz` 直接跳过循环，一次都不写，保证不越界。全程没有 `bl`，是叶子函数，不用保存 `$ra`。`memcpy`/`strlen` 是同一骨架的变体：`memcpy` 多维护一个源指针（`ld.bu` 必须无符号加载，否则 `0x80` 这类高位字节会被符号扩展成垃圾值）；`strlen` 靠读到 `'\0'`（而不是计数器）判断结束。

### 4.3 更复杂的例子：memmove（先判方向，再选路径）

```asm
memmove:
    move        $t0, $a0            /* 保存原始 dst，作为返回值 */
    beqz        $a2, 4f
    sltu        $t2, $a0, $a1       /* t2 = (dst < src) ? 1 : 0 */
    bnez        $t2, 2f             /* dst < src：正向搬，和 memcpy 一样 */
    /* dst >= src：从尾往前搬 */
    add.d       $a0, $a0, $a2
    add.d       $a1, $a1, $a2
    addi.d      $a0, $a0, -1
    addi.d      $a1, $a1, -1
1:
    ld.bu       $t1, $a1, 0
    st.b        $t1, $a0, 0
    addi.d      $a0, $a0, -1
    addi.d      $a1, $a1, -1
    addi.d      $a2, $a2, -1
    bnez        $a2, 1b
    b           4f
2:
    ld.bu       $t1, $a1, 0
    st.b        $t1, $a0, 0
    addi.d      $a0, $a0, 1
    addi.d      $a1, $a1, 1
    addi.d      $a2, $a2, -1
    bnez        $a2, 2b
4:
    move        $a0, $t0
    jr          $ra
```

`memcpy` 假设区间不重叠；如果 `dst` 在 `src` 后面且区间重叠，从头往前搬会用新值覆盖还没读到的旧值。`memmove` 用 `sltu`（无符号比较地址）判断方向：`dst < src` 正向搬（和 `memcpy` 一样，永远读在写前面）；`dst >= src` 反过来从最后一个字节开始往前搬，同样保证"永远读在写前面"。

**课堂快速复习**：给 `memmove(buf, buf+2, 6)` 和 `memmove(buf+2, buf, 6)`（同一个初始 `buf`），口头过一遍两次调用各自走哪条路径、结果是什么，不用再像第 7 次课那样整段推演，重点是唤醒记忆。

### 4.4 更复杂的例子：strcmp（一个循环两条退出路径）

```asm
strcmp:
1:
    ld.bu       $t0, $a0, 0
    ld.bu       $t1, $a1, 0
    bne         $t0, $t1, 2f      /* 字节不同：跳出去算差值 */
    beqz        $t0, 3f           /* 两边都读到 '\0'：字符串相等 */
    addi.d      $a0, $a0, 1
    addi.d      $a1, $a1, 1
    b           1b
2:
    sub.d       $a0, $t0, $t1
    jr          $ra
3:
    move        $a0, $zero
    jr          $ra
```

`bne` 判"两个字节不同，提前跳出去算差值"，`beqz` 判"两边同时读到 `'\0'`，正常结束、返回 0"。两条路径通向不同的返回值——本课要独立实现的 `strncmp`（§4.6）正是在这个骨架上多加一个"最多比 n 个"的限制。

### 4.5 更复杂的例子：zero_and_copy（非叶子函数）

```asm
zero_and_copy:
    addi.d      $sp, $sp, -32
    st.d        $ra, $sp, 24
    st.d        $s0, $sp, 16     /* s0 = dst，跨三次 bl 保存 */
    st.d        $s1, $sp, 8      /* s1 = src，跨三次 bl 保存 */
    move        $s0, $a0
    move        $s1, $a1
    move        $a1, $zero        /* memset(dst, 0, dst_size) */
    bl          memset
    move        $a0, $s1          /* strlen(src) */
    bl          strlen
    move        $a2, $a0          /* memcpy(dst, src, len) */
    move        $a1, $s1
    move        $a0, $s0
    bl          memcpy
    ld.d        $ra, $sp, 24
    ld.d        $s0, $sp, 16
    ld.d        $s1, $sp, 8
    addi.d      $sp, $sp, 32
    jr          $ra
```

内部依次 `bl memset`/`bl strlen`/`bl memcpy`，三次调用意味着 `$ra` 必须先存后取；`dst`/`src` 要跨这三次调用存活，`$a0`-`$a2`/`$t0`-`$t8` 都会被三个被调用者自由覆盖，所以借用 `$s0`/`$s1`（callee-saved）。这个函数会在单元三 `kernel_integration_demo()` 第①步里被真正用到。

### 4.6 独立实现任务：strncmp（不讲代码，只讲要求）

**函数原型**：`int strncmp(const char *a, const char *b, size_t n)`——`strcmp` 加一个"最多比较 n 个字节"的限制：

- `n == 0`：不读取任何字节，直接返回 0。
- 比较到第 n 个字节为止：前 n 个字节全部相同就返回 0，即使 n 之外还有不同字符。
- n 个字节以内出现不同字节：返回那对字节的差值（同 `strcmp`：无符号加载后相减，教学简化）。
- n 个字节以内两边同时读到 `'\0'`：直接判等，不需要凑满 n 次。

**这是本单元唯一的编程任务，不给汇编代码**，学生自己在 `lib/string.S` 里独立实现（可以参考 §4.4 `strcmp` 的骨架，但要自己想清楚"多一个计数器该插在循环的哪个位置"）。具体验收方式见 `lab.md`。

## 5. 单元二：定时器中断（第 2–3 学时）

### 5.1 定时器三个 CSR

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

### 5.2 两层使能

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

### 5.3 异常与中断共享入口

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

### 5.4 为什么中断入口要保存更多寄存器

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

### 5.5 暂停 ≠ 停止：`timer_pause`/`timer_resume` 与 `timer_stop` 的区别

`timer_stop()` 只关分源开关（`ecfg_disable_timer_line()`），`TCFG` 的配置(周期倒数)其实原封不动地留在硬件里，只是不再触发中断——严格说它的效果本来就是"暂停"，只是接口起名叫 `stop`，容易让人误以为定时器被彻底清空了。Task3.7 要求学生把这层语义显式拆开，写出 `timer_pause()`/`timer_resume()`：函数体和 `timer_stop()` 几乎一样（同样是开/关 `ECFG` 对应位），但接口名字要让调用者一眼看出"这个中断以后还会不会回来"——这是"接口语义比实现更重要"的一次具体练习。

### 5.6 实测数据（供课堂对照）

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

## 6. 单元三：miniOS 内核服务整理 + 集成demo（第 4 学时，跟做教程）

本单元不要求学生独立设计，讲义直接给出服务地图和集成 demo 的完整代码，课堂目标是"跟着抄一遍、亲手跑通"，体会集成起来是什么效果，而不是从零构思。

### 6.1 服务地图（直接给出，不要求学生重画）

```text
boot/start.S _start
  ├─ clear_bss                         第2次课
  ├─ kernel_main                       第1次课
  │    ├─ printk → uart_puts → uart_putc     第1/8次课（直接碰硬件：MMIO）
  │    ├─ regs_alu / mem_fp / branch_loop / stack_abi  第3-6次课（纯计算，无外部依赖）
  │    ├─ memset/memcpy/strlen/memmove/strcmp/zero_and_copy/strncmp  第2/7/11次课（被几乎所有模块依赖）
  │    ├─ syscall_dispatch → sys_write        第8次课（接口收窄，内部仍调用 uart_putc）
  │    └─ exception_init                      第9次课（写 CSR.EENTRY）
  └─ exception_entry（硬件触发，不是 kernel_main 调用）
       ├─ Ecode!=0 → exception_handler        第9次课：同步异常
       └─ Ecode==0 → irq_dispatch → timer_*   第11次课：定时器中断
```

### 6.2 边界问答（直接给出答案，学生对照代码理解即可）

| 问题 | 答案要点 |
|---|---|
| 谁能直接碰硬件（MMIO/CSR）？ | `uart_putc`、`irq.c` 的 CSR 操作、`exception_entry`；其余模块都通过接口调用 |
| 哪个模块被依赖最多？ | `string.S`（`memset`/`memcpy`/`strlen`），几乎每个后续模块都用它 |
| 哪两个模块表面不同、底层同构？ | `printk` 与 `sys_write`——都是 `uart_putc` 的封装，只是接口面不同 |
| 哪个入口不是被 C 代码"调用"，而是硬件跳转？ | `exception_entry`（连接 `_start`/`clear_bss`/`kernel_main` 的普通调用链之外） |

### 6.3 集成模拟：跟做 kernel_integration_demo()

单纯给出服务地图，容易停留在"我知道各模块是什么"，却没有亲手体会"操作系统就是把这些服务模块串起来、靠事件驱动往前推进"这件事。所以本单元给出完整代码，让学生照抄进 `kernel/main.c`，依次跑：库函数（`memset`/`memcpy`/`strlen`）→系统调用正常路径 + 非法 fd 防御性测试（`syscall_dispatch`）→同步异常（`break`）→异步中断 + 暂停/恢复（复用单元二 Task3.7 的 `timer_pause`/`timer_resume`），最后打印集成验收串。

这里第①步用到的 `memset`/`memcpy`/`strlen` 正是单元一刚复习过的函数——从"读懂它怎么实现"到"看它被真正集成进内核 demo"，是本课三个单元前后呼应的地方。完整代码见 `lab.md` §6。

## 7. 课堂 Demo

1. 单元一：口头过一遍 `memmove`/`zero_and_copy` 的执行路径（§4.3/§4.5），提醒学生 `strncmp` 要自己写、不给代码。
2. 对照 `main.c` 调用与寄存器，走一遍定时器 `timer_init`/`irq_dispatch`。
3. GDB 在中断处理路径看 `$a0`/`$a1` 怎么从 `ESTAT`/`ERA` 传进 `exception_handler`。
4. 教师现场写一遍 `timer_read_remaining()`，`make run` 让学生看到 TVAL 被重新装载，再放手让学生自己实现。
5. 教师现场写一遍 `timer_pause()`/`timer_resume()`，强调和 `timer_stop()` 函数体几乎一样、但接口语义不同（对照 §5.5）。
6. 单元三：教师投影 `kernel_integration_demo()` 完整代码，逐段讲解"这一步对应哪个服务、主动调用还是被动响应"，然后放手让学生照抄、`make run`、截图。

## 8. 实验实践

**Task A**　跑通 `make run`，核对定时器 5 个 tick 与 `week11-irq-kernel-recap check done`。

**Task B**　修改 `TIMER_COUNT`，记录至少两组不同取值下的实测 tick 间隔（粗略计时即可）。

**Task C**　书面回答：为什么 `irq_dispatch` 路径里 `exception_handler` 返回 `era` 而不是 `era+4`？对照第 9 次课的 `break` 路径说明差异原因。

**Task D（必做，写代码）**　实现 `timer_read_remaining()`（读 TVAL），在 `irq_dispatch` 里打印出来，验证周期模式自动重装（对应 lab.md Task3.5）。

**Task E（必做，写代码）**　实现三档变速 tick：用速度表在 `irq_ticks()==2/4` 时重新调用 `timer_init()` 切档（对应 lab.md Task3.6）。

**Task F（必做，写代码）**　实现 `timer_pause()`/`timer_resume()`，书面说明它们与 `timer_stop()`/`timer_init()` 的语义差异（对应 lab.md Task3.7，见 §5.5）。

**Task G（单元一，重点，独立实现）**　独立实现 `strncmp`，不给代码，`make run` 跑通后截图即为提交（对应 lab.md §4）。

**Task H（单元三，跟做）**　照抄 `kernel_integration_demo()` 骨架代码进 `kernel/main.c`，`make run` 跑通、截图（对应 lab.md §6）。

**Task I（选做）**　按 §6.3 复现"不清中断源"的故障，记录现象并解释原因（对应 lab.md Task8）。

## 9. AI 共学

- 单元一 `strncmp`：允许对照 ABI 检查；**禁止直接向 AI 索要完整实现代码**，独立实现是本单元唯一的编程任务。
- 单元二/三：允许协助核对 CSR 位定义、排查 `kernel_integration_demo()`/`timer_pause`/`timer_resume` 的编译报错；`TIMER_COUNT` 调参、TVAL 读数、三档变速 tick、暂停/恢复、非法 fd 防御性测试的真实输出必须来自本机 `make run`，不得编造。

## 10. 思考与拓展

1. `strncmp` 和 `strcmp` 共用同一个"字节比较+提前退出"的骨架，为什么不能直接调用 `strcmp` 再截断结果？
2. 若一个中断处理函数执行时间过长，会挡住其他更紧急的中断，如何权衡？
3. `irq_dispatch` 目前只认识定时器，如果要接入 UART 接收中断，接口应该怎么扩展？
4. 服务地图里，哪个模块最适合作为板级迁移时"只改这一层"的边界？

## 11. 板书

```text
单元一：memset/memcpy/strlen/memmove/strcmp/zero_and_copy 复习 → 独立实现 strncmp（不给代码）
单元二：定时器三件套 TCFG/TVAL/TICLR，两层开关 ECFG+CRMD.IE，共享入口 Ecode==0/!=0
       timer_pause/resume ≠ timer_stop/init：暂停保留状态，停止/重启不保留
单元三：服务地图（直接给出）→ kernel_integration_demo 跟做（直接给出代码）→ make run 截图
三单元呼应：单元一的 memset/memcpy/strlen 就是单元三 demo 第①步真正用到的函数
```

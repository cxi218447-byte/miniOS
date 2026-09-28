# 第 11 次课实验指导书：库函数独立实现 + 中断/定时器实验 + miniOS 内核服务整理

> 技术编号：`11`　|　建议检查点：`11-irq-kernel-recap`　|　4 学时连排（纯实验课）  
> 称"第 11 次课"，不称"第 11 周"。配合讲义：`docs/11/lecture_notes.md`。  
> **环境总手册：** `docs/student_env_runbook.md`  

## 0. 克隆仓库到本地（首次 / 换新位置 / GitHub 打不开用 Gitee）

**只需做一次**——已经克隆过、能正常 `cd` 进仓库的同学跳过，直接看下面「实验环境与准备」。
以下命令一律在 **WSL Ubuntu** 终端里执行，**不要**在 Windows PowerShell 里 `clone`
（原因：Windows 版 Git 会把换行符转成 CRLF，跟 WSL 的 LF 混用会导致 `git status`
显示一大片文件"modified"，甚至切分支时报错）。

**默认克隆**（在当前目录下新建 `miniOS` 文件夹）：

```bash
git clone https://github.com/cxi218447-byte/miniOS.git
cd miniOS
```

**想放到指定的新位置**：在命令末尾加目标路径（目录不存在会自动创建）：

```bash
git clone https://github.com/cxi218447-byte/miniOS.git "/mnt/d/你的路径/miniOS"
```

**GitHub 打不开（校园网常见）？** 换成 Gitee 镜像，内容与 GitHub 保持同步：

```bash
git clone https://gitee.com/cxi218447-bytes/miniOS.git
cd miniOS
```

已经用 GitHub 地址克隆过、想改连 Gitee 的话不用重新克隆：

```bash
git remote set-url origin https://gitee.com/cxi218447-bytes/miniOS.git
git fetch --tags
```

## 1. 实验目标

本实验配合 4 学时（每学时 45 分钟）教学，分成三个前后衔接的单元。完成后应能：

1. 独立实现一个新的库函数（`strncmp`），不看提示把寄存器/访存/循环/调用约定组合起来。
2. 说清定时器三个 CSR（`TCFG`/`TVAL`/`TICLR`）与两层使能（`ECFG`/`CRMD.IE`）的分工。
3. 跑通一个真实的周期性定时器中断 demo，并能调参观察 tick 节奏变化。
4. 解释异常与中断为何共享同一个 `EENTRY` 入口，以及中断入口为何要保存更多寄存器。
5. **亲手写代码**验证定时器周期重装（读 TVAL）、实现三档变速 tick、实现 `timer_pause()`/`timer_resume()`。
6. 跟着指引把 `kernel_integration_demo()` 抄进 `kernel/main.c` 并跑通，把启动、库函数、系统调用（含防御性测试）、异常、中断（含暂停/恢复）这条服务链真正串联起来一遍。

## 2. 实验环境与准备（必须先做对）

### 2.1 必须在 WSL/Ubuntu 中构建

```powershell
wsl -d Ubuntu
```

提示符变为 `user@host:~$` 后：

```bash
cd "/mnt/d/工作/日常教学/2026-2027第一学期/汇编语言/miniOS"
ls Makefile
which make
which loongarch64-linux-gnu-gcc
which qemu-system-loongarch64
```

不要在 `PS D:\...>` 提示符下直接执行 `make`。退出 QEMU：先按 `Ctrl+a`，再按 `x`。

### 2.2 建立个人实验分支

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-11-lab 11-irq-kernel-recap
```

`my-11-lab` 是学生本地分支，远程没有同名分支是正常现象。若教师尚未发布 tag，以课堂指定 checkpoint 为准。

### 2.3 重点文件

```text
include/string.h       （单元一：strncmp 声明加在这里）
lib/string.S            （单元一：memset/memcpy/strlen/memmove/strcmp/zero_and_copy 已有，strncmp 待你实现）
boot/start.S          （exception_entry，第9次课已有，本课升级为144字节栈帧）
kernel/exception.c    （exception_handler，本课新增 Ecode==0 分支）
kernel/irq.c          （本课可运行 demo：timer_init/irq_dispatch/timer_stop；Task3.5/3.7 在此新增 timer_read_remaining/timer_pause/timer_resume）
include/irq.h         （Task3.7 在此补充 timer_pause/timer_resume 声明）
kernel/main.c         （单元一验收、单元二定时器验收段、单元三 kernel_integration_demo 都写在这里）
kernel/syscall.c      （第8次课已有，单元三会调用 syscall_dispatch/SYS_WRITE）
include/syscall.h
```

## 3. 实验安排

| 教学单元 | 对应学时 | 实验内容 | 建议完成点 |
|---|---|---|---|
| 单元一：库函数独立实现 | 第 1 学时 | §4 独立实现 `strncmp` | 第 1 学时结束 |
| 单元二：定时器中断上机 | 第 2–3 学时 | §5 Task 1–3.7 | 第 3 学时结束 |
| 单元三：内核服务整理 + 集成demo（跟做） | 第 4 学时 | §6 跟做 `kernel_integration_demo()` | 第 4 学时结束 |

## 4. 单元一：库函数独立实现（第 1 学时）

第 6/7 次课学过 `memset`/`memcpy`/`strlen`/`memmove`/`strcmp`/`zero_and_copy` 六个函数，
代码已经在仓库的 `lib/string.S` 里（本次 checkpoint 起点就带着，不用重写）。本单元
**只有一个编程任务**：独立实现第七个——`strncmp`，`strcmp` 的"最多比较 n 个字符"
版本。不给任何汇编代码，自己写。

**提交要求只有一个：** 跑通后截图，上传截图即可，不用交报告（对应第 11 节提交清单）。

### 4.1 任务：实现 `strncmp`

**函数原型**：`int strncmp(const char *a, const char *b, size_t n)`

| 寄存器 | 含义 |
|---|---|
| `$a0` | 字符串 `a` 的地址 |
| `$a1` | 字符串 `b` 的地址 |
| `$a2` | `n`：最多比较的字节数 |
| 返回（`$a0`） | 0：前 n 个字节相等（或双方在 n 个字节内已同时遇到 `'\0'`）；非 0：第一个不同字节的差值 |

**行为约定**（对照 `strcmp`，只是多了一个"最多比几个"的限制）：

- `n == 0`：不读取 `a`/`b` 的任何字节，直接返回 0。
- 比较到第 n 个字节为止：如果前 n 个字节全部相同，即使后面还有不同字符，也
  返回 0（不能比过 n）。
- 如果在第 n 个字节以内遇到不同字节，返回那一对字节的差值（同 `strcmp`：
  无符号加载后相减，教学简化，不做饱和处理）。
- 如果在第 n 个字节以内两边同时读到 `'\0'`，直接判定相等，返回 0（不需要凑满 n 次）。

**要求**：

1. 在 `include/string.h` 里加一行声明。
2. 在 `lib/string.S` 里独立实现——自己写循环处理 `n`，不允许直接调用现成的
   `strcmp` 再敷衍了事（那样处理不了 `n` 的截断）。
3. 在 `kernel/main.c` 里用 `printk` 验证，至少覆盖以下三种情况：
   - 前 n 个字节相同、n 之外不同 → 应判定相等
   - 在 n 个字节以内出现不同字节 → 应判定不等
   - `n == 0` → 应判定相等

### 4.2 验收与提交

```bash
make clean
make
make run
```

串口里能看到你自己写的三行验证输出（内容和上面三种情况对应，格式自定）。

**截图这部分串口输出，上传截图。就这一步，不用交代码、不用写报告。**

## 5. 单元二：定时器中断上机（第 2–3 学时）

### Task1 精读代码

- 对照讲义 §5.1–§5.3，在 `kernel/irq.c` 逐行标注：哪几行是"配置"，哪几行是"使能"，哪一行是"清源"。
- 在 `kernel/exception.c` 找到 `ecode == 0` 分支，说明它为什么不用 `era + 4`。

### Task2 运行验收

```bash
make clean
make
make run
```

核对串口输出（`Ctrl+a` 再 `x` 退出 QEMU）：

```text
timer_init: periodic timer interrupt enabled
tick #1
tick #2
tick #3
tick #4
tick #5
collected 5 timer ticks via interrupt, timer_stop() called
week11-irq-kernel-recap check done
```

### Task3 调参实验

- 修改 `kernel/main.c` 中的 `TIMER_COUNT`（例如改成原值的一半、两倍），重新 `make run`，记录 tick 出现的快慢变化（用肉眼感受节奏即可，不要求精确计时）。
- 写一句话结论：`TIMER_COUNT` 与 tick 间隔是正相关还是负相关？

### Task3.5 实现并验证 timer_read_remaining()（必做，写代码）

- 在 `kernel/irq.c` 里新增一个函数（不需要改 `include/irq.h`，只在本文件内部使用），仿照已有的 `timer_irq_clear()` 写法，把 `csrwr` 换成 `csrrd`、CSR 编号换成 `0x42`（TVAL，只读）：

  ```c
  static inline unsigned long timer_read_remaining(void)
  {
      unsigned long v;
      __asm__ volatile("csrrd %0, 0x42" : "=r"(v));
      return v;
  }
  ```

- 在 `irq_dispatch` 打印 `tick #N` 之后追加一行，打印当前 TVAL：

  ```c
  printk("  TVAL now=0x");
  printk_hex(timer_read_remaining());
  printk("\n");
  ```

- 重新 `make run`，核对：每次 tick 打印的 TVAL 都接近初始 InitVal（`TIMER_COUNT`），而不是持续减到 0 不再变化——用代码亲手验证"周期模式会自动重装初值"这句话，而不是只背下来。

### Task3.6 实现三档变速 tick（必做，写代码）

不是只切一次速度，而是用一个**速度表**把 5 次 tick 分成三档，在 `kernel/main.c` 里改造循环：

```c
static const unsigned long speed_table[3] = {
    TIMER_COUNT,        /* 第0档：原速度，tick 0-1 */
    TIMER_COUNT / 4,     /* 第1档：4倍速，tick 2-3 */
    TIMER_COUNT / 16,    /* 第2档：16倍速，tick 4 */
};
unsigned long stage = 0;

timer_init(speed_table[0]);
printk("timer_init: periodic timer interrupt enabled\n");

while (irq_ticks() < 5) {
    if (irq_ticks() == 2 && stage == 0) {
        timer_init(speed_table[1]);
        stage = 1;
    } else if (irq_ticks() == 4 && stage == 1) {
        timer_init(speed_table[2]);
        stage = 2;
    }
    __asm__ volatile("idle 0");
}
```

- 关键考点：想清楚"只改局部变量 `TIMER_COUNT` 会不会生效"——不会，它只在最开始那一次调用 `timer_init()` 时起作用，必须**重新调用一次 `timer_init()`** 才能真正改写硬件的 `TCFG` 配置；`stage` 变量是为了保证每一档只切换一次，不要在还没到下一个阈值时重复调用。
- 写一句话结论：`timer_init()` 能不能在定时器已经跑起来的情况下被再次调用？会发生什么（提示：`timer_init` 内部本身就是"整体重新配置+重新使能"，可以放心重复调用）。
- 验收：观察到明显的三段节奏——慢、快、更快。

### Task3.7 实现 timer_pause()/timer_resume()（必做，写代码）

`timer_stop()` 只是"关分源开关"，`TCFG` 的配置(周期倒数)其实还在，只是不再触发中断。这个任务要求把"暂停/恢复"和"彻底停止"在接口层面分开，写出语义更清楚的一对函数。

在 `kernel/irq.c` 新增（可以直接复用已有的 `ecfg_enable_timer_line`/`ecfg_disable_timer_line`）：

```c
/* 暂停：只关分源开关，TCFG 配置和已计数的 tick 都保留，可随时恢复 */
void timer_pause(void)
{
    ecfg_disable_timer_line();
}

/* 恢复：重新打开分源开关，不重新写 TCFG——直接从暂停前的状态继续倒数 */
void timer_resume(void)
{
    ecfg_enable_timer_line();
}
```

在 `include/irq.h` 里加上这两个函数的声明（参照 `timer_stop`/`timer_init` 已有的写法）。

- 书面回答：`timer_pause()`/`timer_stop()` 两个函数的**函数体**几乎一样，为什么还要分开定义两个名字？（提示：接口语义比实现更重要——调用者看函数名就该知道"这个中断以后还会不会回来"）
- 这两个函数会在单元三的 `kernel_integration_demo()` 里实际用到，先写好待用。

### 单元二阶段验收

- `make run` 输出与 Task2 摘录一致，且能看到 Task3.5 新增的 TVAL 打印行、Task3.6 三档变速的节奏变化。
- 有至少两组 `TIMER_COUNT` 取值的调参记录（Task3）。
- 能解释中断入口为什么要保存比第 9 次课更多的寄存器（讲义 §5.4）。
- 能解释为什么 Task3.6 必须重新调用 `timer_init()` 才能生效，而不是改个局部变量就够了。
- `timer_pause()`/`timer_resume()` 编译通过（Task3.7），能说清它们和 `timer_stop()`/`timer_init()` 的语义差异。

## 6. 单元三：miniOS 内核服务整理 + 集成demo（第 4 学时，跟做即可）

本单元**不要求独立画图、不要求独立设计代码**——讲义直接给出服务地图和完整
代码，你只需要读懂、照抄进 `kernel/main.c`、跑通、截图。

### 6.1 服务地图（阅读理解，讲义 §6.1 已给出）

对照 `docs/11/lecture_notes.md` §6.1 的服务地图，在代码里找到对应的每一行调用，
确认自己能看懂"谁调用谁"。不需要自己重新画一遍。

### 6.2 边界问答（阅读理解，讲义 §6.2 已给出答案）

读一遍讲义 §6.2 的四个问答，对照代码确认理解，不需要书面重新作答。

### 6.3 跟做 kernel_integration_demo()（必做，照抄代码）

在 `kernel/main.c` 里新增一个函数 `kernel_integration_demo(void)`，紧跟在
`week11-irq-kernel-recap check done` 之前调用它。下面是**完整代码，直接照抄**：

```c
#include "syscall.h"
#include "string.h"

static void kernel_integration_demo(void)
{
    char buf[32];
    const char *msg = "hello from syscall\n";
    unsigned long start_ticks;
    long bad_ret;

    /* 1. 库函数（单元一刚复习过的 memset/memcpy/strlen） */
    memset(buf, 0, sizeof(buf));
    memcpy(buf, msg, strlen(msg));
    printk("integration: buf=");
    printk(buf);

    /* 2. 系统调用：正常路径 */
    syscall_dispatch(SYS_WRITE, 1, (long)msg, (long)strlen(msg));

    /* 3. 系统调用：防御性测试，fd=99 非法，期望返回 -1 */
    bad_ret = syscall_dispatch(SYS_WRITE, 99, (long)msg, (long)strlen(msg));
    if (bad_ret == -1) {
        printk("integration: illegal fd correctly rejected (-1)\n");
    } else {
        printk("integration: BUG - illegal fd not rejected!\n");
    }

    /* 4. 同步异常 */
    __asm__ volatile("break 0");

    /* 5. 异步中断 + 暂停/恢复（注意 irq_ticks() 全程累计，要用基准值+N，不能直接 <N） */
    start_ticks = irq_ticks();
    timer_init(0x800000UL);
    while (irq_ticks() < start_ticks + 2) {
        __asm__ volatile("idle 0");
    }
    timer_pause();
    printk("integration: timer paused, ticks frozen at ");
    printk_udec(irq_ticks());
    printk("\n");
    timer_resume();
    while (irq_ticks() < start_ticks + 5) {
        __asm__ volatile("idle 0");
    }
    timer_stop();

    printk("kernel_integration_demo: OS lifecycle simulated\n");
}
```

**提示（容易踩的坑）**：`irq_ticks()` 是**全程累计**的全局计数，单元二已经把它跑到了 5，
`timer_stop()`/`timer_pause()` 都不会把它清零，所以上面代码用"启动时的基准值 `start_ticks` + N"
而不是直接 `< N`——这一点代码里已经处理好了，照抄即可，理解一下为什么这么写。

这段代码依赖单元二 Task3.7 写好的 `timer_pause`/`timer_resume`，请确认 Task3.7 已完成再做本单元。

### 6.4 验收与提交

```bash
make clean
make
make run
```

核对能看到：库函数结果、系统调用正常路径、非法 fd 被拒绝、`break 0` 触发异常并安全恢复、
"暂停后 tick 数不再变化、恢复后继续变化"、最后的 `kernel_integration_demo: OS lifecycle simulated`。

**截图这部分完整输出，上传截图。这一步不用交代码、不用写报告。**

### Task7 为第 12 次课准备（选做）

- 从选题 A（启动与服务）/ B（板级迁移）/ C（Agent Runtime 雏形）中预选一个方向（第 12 次课会用到）。第 12 次课选题 A 可以直接复用本单元跑好的 `kernel_integration_demo()` 作为展示起点。

### Task8（选做）故障复现

- 临时注释掉 `kernel/irq.c` 中 `irq_dispatch` 里的 `timer_irq_clear()` 调用，重新编译运行，记录现象（提示：会不会卡住/刷屏），解释原因，然后改回来确认恢复正常。

## 7. 验收标准

- 单元一：`strncmp` 独立实现、`make run` 输出你自己写的三行验证，截图。
- 单元二：定时器中断真实跑通，输出与 Task2 摘录一致；能解释 `ESTAT.Ecode` 如何区分异常与中断；`timer_read_remaining()` 打印的 TVAL 能体现周期模式自动重装（Task3.5）；三档变速 tick 效果真实可见（Task3.6）；`timer_pause()`/`timer_resume()` 编译通过（Task3.7）。
- 单元三：`kernel_integration_demo()` 照抄跑通，6 个环节顺序正确、不卡死，截图。

## 8. 提交清单

- [ ] 单元一：`strncmp` 验证截图（串口三行输出）
- [ ] 单元二：实验报告（见第 9 节要求）
- [ ] 单元三：`kernel_integration_demo()` 完整输出截图

## 9. 单元二实验报告要求（只有单元二需要报告，单元一/三截图即可）

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 调参记录（Task3）、三档变速 tick 记录（Task3.6）与故障复现记录（Task8，若完成）
4. `timer_read_remaining()` 的 TVAL 输出摘录（Task3.5）与 `timer_pause`/`timer_resume` 说明（Task3.7）
5. 问题与解决过程（若有）
6. 思考题作答（见讲义 §10）

## 10. AI 共学边界

- 单元一（`strncmp`）：允许对照 ABI 检查；**禁止只交无注释的长代码，禁止直接向 AI 索要完整实现**——这是本单元唯一的编程任务，独立完成才有意义。
- 单元二/三：允许协助核对 CSR 位定义、排查 `kernel_integration_demo()`/`timer_pause`/`timer_resume` 的编译报错；调参、TVAL 读数、变速 tick、集成 demo 与故障复现的真实输出必须来自本机 `make run`，不得编造。

## 11. 思考题

见讲义 `lecture_notes.md` §10。

## 12. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称 |
| Ubuntu 中找不到工具 | 按 `docs/student_env_runbook.md` 安装课程工具链 |
| `undefined reference to 'strncmp'` | 只在 `.h` 声明、没在 `lib/string.S` 实现，或忘了 `.globl strncmp` |
| `strncmp` 在 `n=0` 时崩溃/读到垃圾 | 循环入口要先判断 `$a2==0`，不能先读一个字节再判断 |
| `strncmp` 前 n 相同也被判成不等 | 检查计数减到 0 时是否正确返回相等，而不是继续往后读 |
| tick 一直不出现 | 检查 `ECFG`/`CRMD.IE` 两层开关是否都打开 |
| tick 刷屏停不下来 | 检查 `TICLR` 清源是否被误删（对照 Task8） |
| 单元三 `while (irq_ticks() < 3)` 循环一次都不进 | `irq_ticks()` 全程累计；要用"启动时的基准值 + N"，见 §6.3 提示 |
| 编译报 `timer_pause`/`timer_resume` 隐式声明警告或链接错误 | Task3.7 里 `include/irq.h` 忘了加声明，或 `kernel/main.c` 忘了 `#include "irq.h"` |
| 退不出 QEMU | `Ctrl+a`，再按 `x` |

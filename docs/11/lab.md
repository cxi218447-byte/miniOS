# 第 11 次课实验指导书：中断/定时器实验 + miniOS 内核服务整理

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

本实验配合 4 学时（每学时 45 分钟）教学，分成两个前后衔接的单元。完成后应能：

1. 说清定时器三个 CSR（`TCFG`/`TVAL`/`TICLR`）与两层使能（`ECFG`/`CRMD.IE`）的分工。
2. 跑通一个真实的周期性定时器中断 demo，并能调参观察 tick 节奏变化。
3. 解释异常与中断为何共享同一个 `EENTRY` 入口，以及中断入口为何要保存更多寄存器。
4. **亲手写代码**验证定时器周期重装（读 TVAL）、实现变速 tick，而不只是观察别人写好的代码。
5. 画出 miniOS 当前的内核服务地图，说清模块边界。
6. **亲手写一个 `kernel_integration_demo()`**，把启动、库函数、系统调用、异常、中断这条服务链真正串联跑通一遍，体会"操作系统 = 服务集成 + 事件驱动模拟"。

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

```bash
git fetch --tags
git switch -c my-11-lab 11-irq-kernel-recap
```

`my-11-lab` 是学生本地分支，远程没有同名分支是正常现象。若教师尚未发布 tag，以课堂指定 checkpoint 为准。

### 2.3 重点文件

```text
boot/start.S          （exception_entry，第9次课已有，本课升级为144字节栈帧）
kernel/exception.c    （exception_handler，本课新增 Ecode==0 分支）
kernel/irq.c          （本课可运行 demo：timer_init/irq_dispatch/timer_stop；Task3.5 在此新增 timer_read_remaining）
include/irq.h
kernel/main.c         （定时器中断验收段；Task3.6/Task6 在此新增代码）
kernel/syscall.c      （第8次课已有，Task6 会调用 syscall_dispatch/SYS_WRITE）
include/syscall.h
lib/string.S          （第2/7次课已有，Task6 会调用 memset/memcpy/strlen，见 include/string.h）
```

## 3. 实验安排

| 教学单元 | 对应学时 | 实验内容 | 建议完成点 |
|---|---|---|---|
| 单元一：定时器中断上机 | 第 1–2 学时 | Task 1–3.6 | 第 2 学时结束 |
| 单元二：内核服务整理 | 第 3–4 学时 | Task 4–8 | 第 4 学时结束 |

## 4. 单元一：定时器中断上机（第 1–2 学时）

### Task1 精读代码

- 对照讲义 §4.1–§4.3，在 `kernel/irq.c` 逐行标注：哪几行是"配置"，哪几行是"使能"，哪一行是"清源"。
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

### Task3.6 实现变速 tick（必做，写代码）

- 在 `kernel/main.c` 定时器 `while` 循环里，当 `irq_ticks() == 2` 时，手动再调用一次 `timer_init()`，换一个更小的 `TIMER_COUNT`（比如原值的 1/4），观察后面几次 tick 明显变快。
- 关键考点：想清楚"只改局部变量 `TIMER_COUNT` 会不会生效"——不会，它只在最开始那一次调用 `timer_init()` 时起作用，必须**重新调用一次 `timer_init()`** 才能真正改写硬件的 `TCFG` 配置。
- 写一句话结论：`timer_init()` 能不能在定时器已经跑起来的情况下被再次调用？会发生什么（提示：`timer_init` 内部本身就是"整体重新配置+重新使能"，可以放心重复调用）。

### 单元一阶段验收

- `make run` 输出与 Task2 摘录一致，且能看到 Task3.5 新增的 TVAL 打印行、Task3.6 变速后的 tick 节奏变化。
- 有至少两组 `TIMER_COUNT` 取值的调参记录（Task3）。
- 能解释中断入口为什么要保存比第 9 次课更多的寄存器（讲义 §4.4）。
- 能解释为什么 Task3.6 必须重新调用 `timer_init()` 才能生效，而不是改个局部变量就够了。

## 5. 单元二：miniOS 内核服务整理（第 3–4 学时）

### Task4 画服务地图

- 按讲义 §5.1 的树状结构，自己重新画一遍（可以用画图工具或手绘拍照），标出每个模块对应的课次。

### Task5 边界问答

回答讲义 §5.2 的四个问题：

1. 谁能直接碰硬件（MMIO/CSR）？
2. 哪个模块被依赖最多？
3. 哪两个模块表面不同、底层同构？
4. 哪个入口不是被 C 代码"调用"，而是硬件跳转？

### Task6 实现 kernel_integration_demo()：一次操作系统全服务模拟（必做，写代码）

在 `kernel/main.c` 里新增一个函数 `kernel_integration_demo(void)`，紧跟在服务地图讨论（Task4/Task5）之后、`week11-irq-kernel-recap check done` 之前调用它，依次**真正串联**本课程目前学过的全部内核服务（不是画图，是让它们在同一次运行里真实跑一遍）：

1. **库函数（第2/7次课）**：用 `memset` 清零一段小缓冲区，`memcpy` 拷贝一段文本进去，`strlen` 算出长度，`printk` 打印结果——模拟"内存管理雏形"。
2. **系统调用（第8次课）**：调用 `syscall_dispatch(SYS_WRITE, 1, (long)msg, len)`（而不是直接调 `printk`/`uart_putc`），走一遍"用户态请求内核服务"的路径。
3. **同步异常（第9次课）**：执行一次 `__asm__ volatile("break 0")`，观察 `exception_handler` 打印 ESTAT/ERA 并安全恢复。
4. **异步中断（本课单元一）**：复用 `timer_init`/`irq_ticks`/`timer_stop`，再等待若干次 tick。
5. 全部完成后打印一行 `kernel_integration_demo: OS lifecycle simulated` 作为集成验收串。

**提示（容易踩的坑）**：`irq_ticks()` 是**全程累计**的全局计数，单元一已经把它跑到了 5，`timer_stop()` 不会把它清零。所以这里不能直接写 `while (irq_ticks() < 3)`（条件一开始就已经不成立，循环一次都不会进），要记录"本次开始时的 tick 数"再加 N：

```c
#include "syscall.h"
#include "string.h"

static void kernel_integration_demo(void)
{
    char buf[32];
    const char *msg = "hello from syscall\n";
    unsigned long start_ticks;

    /* 1. 库函数 */
    memset(buf, 0, sizeof(buf));
    memcpy(buf, msg, strlen(msg));
    printk("integration: buf=");
    printk(buf);

    /* 2. 系统调用 */
    syscall_dispatch(SYS_WRITE, 1, (long)msg, (long)strlen(msg));

    /* 3. 同步异常 */
    __asm__ volatile("break 0");

    /* 4. 异步中断（注意 irq_ticks() 全程累计，要用基准值+N，不能直接 <N） */
    start_ticks = irq_ticks();
    timer_init(0x800000UL);
    while (irq_ticks() < start_ticks + 3) {
        __asm__ volatile("idle 0");
    }
    timer_stop();

    printk("kernel_integration_demo: OS lifecycle simulated\n");
}
```

（上面是骨架提示，不要整段照抄，自己理解每一步在调用哪个模块、对应哪次课。）函数直接写在 `kernel/main.c` 里即可，不需要新建源文件（避免改动 `Makefile`）。

验收：`make run` 能看到上述 5 步的真实输出，顺序正确，不卡死、不复位，最后能看到集成验收串。

### Task7 为第 12 次课准备

- 从选题 A（启动与服务）/ B（板级迁移）/ C（Agent Runtime 雏形）中预选一个方向（第 12 次课会用到）。第 12 次课选题 A 可以直接复用 Task6 写好的 `kernel_integration_demo()` 作为展示起点。
- 若倾向选题 B：在服务地图上标出"平台相关"与"平台无关"的模块。

### Task8（选做）故障复现

- 临时注释掉 `kernel/irq.c` 中 `irq_dispatch` 里的 `timer_irq_clear()` 调用，重新编译运行，记录现象（提示：会不会卡住/刷屏），解释原因，然后改回来确认恢复正常。

## 6. 验收标准

- 定时器中断真实跑通，输出与 Task2 摘录一致
- 能解释 `ESTAT.Ecode` 如何区分异常与中断
- `timer_read_remaining()` 打印的 TVAL 能体现周期模式自动重装（Task3.5）
- 变速 tick 效果真实可见，能说明为什么必须重新调用 `timer_init()`（Task3.6）
- 服务地图完整，边界问答有理有据（Task4–5）
- `kernel_integration_demo()` 真实跑通，5 个环节顺序正确、不卡死（Task6）
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行

## 7. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 调参记录（Task3）、变速 tick 记录（Task3.6）与故障复现记录（Task8，若完成）
4. `timer_read_remaining()` 的 TVAL 输出摘录（Task3.5）
5. 服务地图与边界问答（Task4–5）
6. `kernel_integration_demo()` 的完整输出摘录（Task6）
7. 问题与解决过程（若有）
8. 思考题作答

## 8. AI 共学边界

允许协助核对 CSR 位定义、整理服务地图排版、排查 `kernel_integration_demo()` 的编译报错；调参、TVAL 读数、变速 tick、集成 demo 与故障复现的真实输出必须来自本机 `make run`，不得编造。

## 9. 思考题

1. 若一个中断处理函数执行时间过长，会挡住其他更紧急的中断，如何权衡？
2. `irq_dispatch` 目前只认识定时器，如果要接入 UART 接收中断，接口应该怎么扩展？
3. 服务地图里，哪个模块最适合作为板级迁移时"只改这一层"的边界？

## 10. 提交清单

- [ ] 实验报告（PDF/Markdown）
- [ ] 关键输出摘录（含调参对比、变速 tick 记录、TVAL 读数）
- [ ] 服务地图（图片或手绘照片）
- [ ] `kernel_integration_demo()` 的完整输出摘录
- [ ] 需要提交的代码补丁或笔记（按教师要求，含 Task3.5/3.6/6 新增代码）

## 11. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称 |
| Ubuntu 中找不到工具 | 按 `docs/student_env_runbook.md` 安装课程工具链 |
| tick 一直不出现 | 检查 `ECFG`/`CRMD.IE` 两层开关是否都打开 |
| tick 刷屏停不下来 | 检查 `TICLR` 清源是否被误删（对照 Task8） |
| Task6 里 `while (irq_ticks() < 3)` 循环一次都不进 | `irq_ticks()` 全程累计，单元一已经跑到 5；要用"启动时的基准值 + N"，见 Task6 提示 |
| 退不出 QEMU | `Ctrl+a`，再按 `x` |

# 第 8 次课实验指导书：UART 驱动、输出子系统与系统调用 sys_write

> 技术编号：`08`　|　建议检查点：`08-uart-syscall`  
> 称"第 8 次课"，不称"第 8 周"。配合讲义：`docs/08/lecture_notes.md`。  
> 合并原第 10 次课（UART 驱动与输出子系统）+ 原第 11 次课（系统调用 sys_write）。  
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

完成本次课最小可验证闭环，主题：**UART 驱动、输出子系统与系统调用 sys_write**。

本次实验共 **1 个任务**，分两步：

1. **跑通**：给出一段完整的汇编代码，照着抄到新建的 `.S` 文件里，配上头文件声明、
   Makefile 登记、`main.c` 调用，跑起来看到预期输出。
2. **进阶**：只给寄存器约定和要求，不给代码——自己写一段新的汇编逻辑，改掉现
   有代码里"不检查、直接来"的地方，当堂调试通过、截图。

**提交需要两样东西**：① Task1 进阶部分自己写的 `uart_putc_robust` 函数
代码（贴纯文本即可）；② 验证成功后的串口输出截图。不用交完整代码补丁、
不用交报告、不留思考题。

## 2. 实验环境与准备（必须先做对）

### 2.0 课程默认前提

- **第 1 周已完成**：本机装好 **WSL + Ubuntu**（安装步骤按课堂要求，此处不重复）。
- 本实验：**先从 WSL 进入 Ubuntu，再 `cd` 仓库，最后才 `make`。**
- 总手册：`docs/student_env_runbook.md`。

### 2.1 从 WSL 进入 Ubuntu，再 make（每次实验）

| 提示符 | 你在哪 | 能否 `make` |
|---|---|---|
| `PS D:\...>` | Windows PowerShell（未进 Ubuntu） | **不能** |
| `user@xxx:~$` | 已进入 Ubuntu | **能** |

**步骤 1 — 进入 Ubuntu（在 PowerShell 里只做这一步）：**

```powershell
wsl -d Ubuntu
```

或从开始菜单打开 **Ubuntu**。成功标志：提示符变成 `用户名@主机名:~$`（没有 `PS`）。  
若失败：PowerShell 中执行 `wsl -l -v`，用列表中的 NAME：`wsl -d <NAME>`。

**步骤 2 — 已进入 Ubuntu 后：**

```bash
cd "/mnt/<盘符>/.../miniOS"    # D:\foo → /mnt/d/foo
ls Makefile
which make
# 再执行本次课的 git / make
```

退出 QEMU：Ctrl+a 然后 x。  
若在 PowerShell 直接 `make` 出现 `ObjectNotFound`：说明还没执行步骤 1。

- 工具：`make`、`loongarch64-linux-gnu-gcc`、`qemu-system-loongarch64`
- 重点文件（已有）：
  - `kernel/printk.c`（第 1 次课已有的 UART 输出路径：`uart_putc`/`uart_puts`）
  - `include/uart.h`（`UART0_BASE`）
  - `Makefile`（`SRCS_S` 列表——本次课要往里加一个新文件）
- 本次课要**新建**的文件（跑通步骤里创建）：
  - `lib/uart_asm.S`（Task1）

### 2.2 关于 `my-weekXX-lab` 分支（必读）

若本次课要求从 tag 建分支，命令形如（**在已进入的 Ubuntu 里执行**）：

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-08-lab <本次课tag>
```

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `08-uart-syscall`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-08-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. 实验任务（默认均在已进入的 Ubuntu、仓库根目录）

本次任务要新建一个汇编文件，寄存器约定统一沿用之前几次课的调用约定
（第 6 次课）：整数/指针参数从 `$a0` 开始依次排列，返回值放 `$a0`，`jr $ra`
返回；本文件里的函数全部是叶子函数，不涉及 `bl`，不需要保存 `$ra`。

### Task1：UART 输出 —— 从"直接写"到"轮询就绪再写"

**背景**：现在的 `uart_putc`（`kernel/printk.c`）不检查串口是否忙，直接把字节
写进发送寄存器（QEMU 模拟的 16550 从不"忙"，所以能跑，但这不是真实硬件会
用的写法）。16550 的寄存器布局（相对 `UART0_BASE` 的字节偏移）：

| 偏移 | 名称 | 作用 |
|---|---|---|
| `+0` | THR（发送保持寄存器，写） | 写入这里的字节会被发送出去 |
| `+5` | LSR（线路状态寄存器，读） | bit5（`0x20`）= THR 空，为 1 才允许写 THR |

#### Task1 步骤 1（跑通）：新建 `lib/uart_asm.S`，实现 `uart_read_reg`

把下面这段**完整代码**存成新文件 `lib/uart_asm.S`：

```asm
/*
 * 第 8 次课：UART 寄存器读写的汇编实现。
 * uart_read_reg(base, offset)：读 base+offset 处的一个字节。
 * a0 = base 基址，a1 = offset 偏移，返回 a0 = 该地址的字节内容（零扩展）。
 * 叶子函数，不碰 $ra。
 */
    .section .text

    .globl uart_read_reg
uart_read_reg:
    add.d   $t0, $a0, $a1      /* t0 = base + offset */
    ld.bu   $a0, $t0, 0        /* a0 = *(unsigned char *)t0 */
    jr      $ra
```

再做三处"文件代码添加"，让它跑起来：

1. **头文件声明**——在 `include/uart.h` 的 `uart_puts` 声明后面加一行：

   ```c
   unsigned char uart_read_reg(unsigned long base, unsigned long offset);
   ```

2. **Makefile 登记**——打开 `Makefile`，在 `SRCS_S :=` 列表里，`lib/string.S`
   后面加一行：

   ```makefile
   	lib/uart_asm.S \
   ```

3. **在 `kernel/main.c` 里调用一次**——先确认文件顶部 `#include "printk.h"`
   附近加了一行 `#include "uart.h"`（用到 `UART0_BASE` 需要它，目前
   `main.c` 里还没有这一行），然后在 `week08-uart-syscall check done` 那
   行 `printk(...)` **之前**加：

   ```c
   {
       unsigned char lsr = uart_read_reg(UART0_BASE, 5);
       printk("uart LSR now = 0x");
       print_u64_hex(lsr);
       printk("\n");
   }
   ```

```bash
make clean && make && make run
```

能在串口看到一行 `uart LSR now = 0x??`（具体值不重要，能打印出来就说明
`uart_read_reg` 接线正确），即为跑通。这一步不用截图。

#### Task1 步骤 2（进阶，当堂调试 + 截图）：自己写 `uart_putc_robust`

**要求**：在 `lib/uart_asm.S` 里**自己写**一个新函数（不给代码，只给约定）：

```c
void uart_putc_robust(unsigned long base, unsigned char ch);
```

- `$a0` = base，`$a1` = ch（低 8 位有效），无返回值。
- 逻辑：**先轮询 LSR（偏移 `+5`），直到 bit5（`0x20`）为 1，再把 `ch` 写进
  THR（偏移 `+0`）**。不允许在没检查 LSR 的情况下直接写 THR。
- 提示：会用到 `ld.bu` 读 LSR、`andi` 取出 bit5、`beqz`/条件跳转做轮询循环、
  `st.b` 写 THR——都是前几次课学过的指令，组合起来即可。

**接线**（把它接进已有的输出路径）：

1. 在 `include/uart.h` 里加声明 `void uart_putc_robust(unsigned long base, unsigned char ch);`。
2. 修改 `kernel/printk.c` 里的 `uart_putc`，把原来"直接 `*uart = ch`"的写法，
   改成调用 `uart_putc_robust(UART0_BASE, (unsigned char)ch);`。

**验收**：

```bash
make clean && make && make run
```

**要求串口的完整输出内容和之前完全一样**（`Hello miniOS...` 一直到
`week11-irq-kernel-recap check done` 全部照常打印，一个字符都不能丢、也不能
卡住不动）——因为现在每一个字符的发送都要先经过你写的轮询逻辑，只要有一
处写错（比如 bit 位判断反了、忘记清零跳转条件），要么整机卡死不动，要么输
出乱码，当堂调，调通为止。

调通之后，提交下面两样东西：

**代码：请提交你新写的 `uart_putc_robust` 函数代码**

把 `lib/uart_asm.S` 里 `uart_putc_robust` 这一段原样贴在下面的文本框里（纯文本即可，不用上传图片）。

**截图：贴出串口从 `Hello miniOS on LoongArch64` 到 `week11-irq-kernel-recap check done` 的完整输出截图**

证明换成轮询版本后行为不变，这是本次要交的截图。

## 4. 验收标准

- `uart_putc_robust` 必须先轮询 LSR（偏移 `+5`），等 bit5（`0x20`）为 1 之后
  才把字符写进 THR（偏移 `+0`）；不允许跳过检查直接写 THR。
- 代码里要有真正的轮询循环（`ld.bu` 读 LSR、`andi` 取出 bit5、根据结果条件
  跳转），而不是恒真判断或死代码。
- `uart_putc_robust` 是叶子函数：不使用、不保存 `$ra`；寄存器约定为
  `$a0` = base，`$a1` = ch（低 8 位有效），无返回值。
- 截图里的串口输出必须从 `Hello miniOS on LoongArch64` 完整打印到
  `week11-irq-kernel-recap check done`，字符不丢、不乱码、程序不卡死。

## 5. 报告要求

本次实验不要求提交单独的实验报告；学生提交的"报告正文"就是 Task1 里贴的
`uart_putc_robust` 汇编代码文本本身。批改时对照上面的验收标准逐条核对这段
代码和配套截图即可，不需要额外的文字说明。

## 6. 验收与提交

- Task1：串口从 `Hello miniOS...` 到 `week11-irq-kernel-recap check done`
  完整无误（1 张截图）。
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行。

**提交清单**：

- [ ] Task1 自己写的 `uart_putc_robust` 函数代码（纯文本）
- [ ] Task1 进阶截图（轮询版 `uart_putc_robust` 接入后的完整串口输出）

不用交代码补丁、不用写报告、不留思考题。

## 7. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称；确认第 1 周已安装 Ubuntu |
| Ubuntu 里 `command not found: make` | 见 runbook 安装交叉工具链 |
| 找不到 Makefile | 检查是否已在 Ubuntu 中 `cd` 到 miniOS 根目录 |
| `undefined reference to 'uart_read_reg'`（或 `uart_putc_robust`） | 新 `.S` 文件没加进 `Makefile` 的 `SRCS_S`，或函数名忘了写 `.globl` |
| `'UART0_BASE' undeclared`（在 `kernel/main.c` 里） | `main.c` 顶部没加 `#include "uart.h"` |
| 加了轮询后串口卡住不再输出 | `uart_putc_robust` 里 bit5 判断反了（该"为 1 才发"写成了"为 0 才发"），或跳转方向搞反导致死循环 |
| 加了轮询后前面几行正常、后面突然乱码/卡住 | 检查 LSR/THR 的偏移有没有写反（`+5` 是 LSR，`+0` 是 THR），或者忘了每次循环都重新 `ld.bu` 读最新的 LSR 值 |
| 退不出 QEMU | Ctrl+a 然后 x |

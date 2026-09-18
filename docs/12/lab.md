# 第 12 次课实验指导书：板级迁移 + 综合实验：从 miniOS 到 Agent OS

> 技术编号：`12`　|　建议检查点：`12-board-agent-demo`　|　4 学时连排（纯实验课）  
> 称"第 12 次课"，不称"第 12 周"。配合讲义：`docs/12/lecture_notes.md`。  
> 合并原「QEMU 到 2K0300 启动与 UART 适配」+ 原「综合实验：从 miniOS 到 Agent OS」。  
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

1. 完成 QEMU virt vs 2K0300 差异表，指出仓库中平台相关文件/宏。
2. 在板端跑通 week01–08 的全部验收输出，与 QEMU 版一致（week09 起卡住
   属已知边界，见 Task4）。
3. 脱稿讲述全课程三阶段主线，完成一个可运行、可讲解的综合展示。
4. 提交架构图、关键汇编注释、真实运行记录，以及"下一迭代 3 件事"。

## 2. 实验环境与准备（必须先做对）

### 2.1 必须在 WSL/Ubuntu 中构建

在 Windows PowerShell 中进入 Ubuntu：

```powershell
wsl -d Ubuntu
```

提示符变为 `user@host:~$` 后，再进入仓库并检查工具：

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
git switch -c my-12-lab 12-board-agent-demo
```

`my-12-lab` 是学生本地分支，远程没有同名分支是正常现象。若教师尚未发布 tag，以课堂指定 checkpoint 为准。

### 2.3 重点文件

```text
include/uart.h
kernel/linker.ld
kernel/printk.c
boot/start.S
kernel/exception.c        （Task5.2 异常分类）
include/kmalloc.h、kernel/kmalloc.c   （Task5.1，需新建）
（综合展示阶段：按选题追加全课程相关模块）
```

## 3. 实验安排

| 教学单元 | 对应学时 | 实验内容 | 建议完成点 |
|---|---|---|---|
| 单元一：板级迁移 | 第 1–2 学时 | Task 1–4 | 第 2 学时结束 |
| 单元二：综合展示 | 第 3–4 学时 | Task 5–8 | 第 4 学时结束 |

## 4. 单元一：板级迁移（第 1–2 学时）

**人手一块真实 2K0300 板卡，这一单元照着
[board_2k0300_setup.md](board_2k0300_setup.md) 从头跟到尾做，是必做项。**
那份文档从接线开始，一路给到改哪些文件、抄哪些代码、编译命令、怎么把
镜像送上板、怎么跳转执行，跟着做就行。

### Task1 差异表

跟着 `board_2k0300_setup.md` §4 做完平台拆分之后，把 QEMU virt 和 2K0300
两边的入口地址、UART 基址、加载方式、调试手段填成一张对照表——这是复述
你刚刚改代码时看到的东西，照着自己改过的文件填就行。

### Task2 平台拆分

按 `board_2k0300_setup.md` §4 一步步做：拆分链接脚本（§4.1）、拆分 UART
平台头文件（§4.2）、`include/uart.h` 按平台切换（§4.3）、`printk.c` 补
轮询逻辑（§4.4）、`Makefile` 加平台开关（§4.5），做完先在 QEMU 上回归
一遍（§4.6），确认没改坏 QEMU 路径再往下走。

### Task3 排错顺序

对照讲义 §4.4 故障分层表和 `board_2k0300_setup.md` §7 的排错表，写出
`_start` → `$sp` → `clear_bss` → UART 的定位顺序，以及"完全无输出/乱码/
传输失败"这几种现象分别先查什么。

### Task4 板端实践

按 `board_2k0300_setup.md` §5-§7 编译 2K0300 版本、传上板、`go` 跳转。

**验收标准（明确封顶）**：板端跑通 week01–08 的全部验收输出（含浮点），
与 QEMU 版逐字节一致，即算完成。**week09（`break` 异常测试）起卡住是
已知的、当前还没解决的边界，不要求解决**——原因是 LoongArch 真机在
`PG=1` 分页模式下的异常向量行为和 QEMU 的 `DA=1` 直接地址模式不一样，
需要官方寄存器手册或参考代码才能继续排查，课堂时间内不强求。跑到
week09 卡住、把那段输出截下来就算完成这部分。

极少数板卡本身有问题（烧坏/买错型号）确实连不上的，走完整模拟方案
+ 风险分析（哪一步最可能出问题、如何验证）作为兜底，需要跟老师说明情况。

### 单元一阶段验收

- 差异表完整。
- `make PLATFORM=2k0300` 能编译过，QEMU 路径没被改坏（§4.6 回归通过）。
- 板端至少跑通 week01–08，与 QEMU 输出比对一致。

## 5. 单元二：综合展示（第 3–4 学时）

### Task5 命令行 shell 骨架（必做）

板级迁移本身工作量填不满 4 学时，这个 Task 把"内核还能再补哪些功能"落成
一个所有人都做、但支持的命令集可深可浅的具体产出：一个跑在 miniOS 里的
最小命令行 shell。做完这个 Task 才有东西可以在 Task6 的展示里现场敲。

**Task5.1 最小内核堆分配器**

实现 `kmalloc`/`kfree`，接口：

```c
void *kmalloc(size_t size);
void kfree(void *ptr);
void kmalloc_stats(unsigned long *used, unsigned long *capacity,
                    unsigned long *free_blocks);
```

- 堆本体用一段静态数组（不依赖 MMU/分页，跟 `boot_stack` 是同一类"编译期
  留好一块内存"的思路），维护一个"从未分配过区域"的位置指针。
- 每块分配出去的内存前面放一个小 header（至少记录大小），`kfree` 时靠
  指针减法找回 header，挂进一条空闲链表。
- `kmalloc` 优先从空闲链表里找能复用的旧块（大小够用即可，不要求最优），
  找不到再从"从未分配过"的区域切新的。
- 不要求写相邻空闲块合并（coalescing）——这是有意留下的真实局限，先把
  "能分配、能回收复用"这条链路跑通即可。

**Task5.2 异常分类**

在第 9–11 次课已有的 `exception_handler` 基础上，把 `ESTAT.Ecode` 翻译成
人能看懂的名字（至少覆盖 ADE/ALE/SYS/BRK/INE 这 5 种，编码查 LoongArch
参考手册异常编码表），打印格式类似 `[exception] BRK(断点) ESTAT=0x... ERA=0x...`。

**Task5.3 命令行循环**

之前的课只教过 `uart_putc`（发送），没教过接收——这里先补一个 `uart_getc`：

```c
char uart_getc(void);
```

跟 `uart_putc` 等 `LSR` 的 TX_EMPTY 位是对称的思路：等 `LSR` 的
"接收数据就绪"位（16550 标准里通常是 bit0，`LSR_DATA_READY_MASK
0x01`）置位，再从数据寄存器（跟 `uart_putc` 写的是同一个偏移，16550
里发送/接收共用一个地址，读为 RBR、写为 THR）读一个字节返回。

有了 `uart_getc`，写一个死循环：从 UART 逐字符读，攒成一行（回车结束）
→ 按空格切成命令名+参数 → 按命令名分发到对应处理函数 → 执行完打印结果
→ 回到读下一行。至少内置这 4 个命令：

| 命令 | 行为 |
|---|---|
| `help` | 列出当前支持的命令名 |
| `echo <text>` | 原样打印 `<text>` |
| `meminfo` | 调 `kmalloc_stats`，打印已用/容量/空闲块数 |
| `crash <ade\|ale\|sys\|brk\|ine>` | 按参数触发对应异常，验证 Task5.2 的分类打印 |

**验收标准**：shell 循环开始前（进入第一次读命令之前）打印一次
`week12-shell check done`，之后 `make run` 能在 QEMU 串口交互式敲上面
4 个命令，行为符合预期（shell 循环本身不退出，这条打印只在启动时出现
一次，不是每条命令都打印）。板端能跑通算加分项，不强制——`crash` 触发
的异常路径在真机上可能撞上 Task4 里记录的 week09 已知边界，不是这个
Task 要解决的问题。

### Task6 选题与演示准备

- 三选一或组合：A 启动与服务 / B 板级迁移（可直接复用单元一成果）/ C Agent Runtime 雏形（可直接复用 Task5 的 shell 作为雏形骨架）。
- 5–8 分钟讲述稿：主线三阶段 + 现场讲解 4 类点（启动路径、一条运算或访存指令、一个循环或调用、一个系统点）。
- 至少脱稿讲清 `_start` 的四行核心指令，及其回连的课次（讲义 §5.2）。

### Task7 运行证据

- 提交真实输出/板级记录/调试摘录（可截断，不可编造），含 Task5 shell 的交互记录。

### Task8 展望

- 写出"若继续做 Agent OS，下一迭代 3 件事"。

## 6. 验收标准

- 能脱稿讲清第 1–2 次课与第 3–6 次课的衔接
- 演示可运行、可追问
- 报告含架构图与汇编注释
- 差异表完整，移植步骤可执行
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行
- Task5 命令行 shell 能跑通，至少 `help`/`echo`/`meminfo`/`crash` 四个内置命令行为正确

## 7. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 对核心代码/指令的简要注释或流程图
4. 问题与解决过程（若有）
5. 思考题作答

## 8. AI 共学边界

允许整理移植检查单、架构图与报告润色；地址切勿臆造，展示追问必须学生本人回答。

## 9. 思考题

1. 为何先移植输出再移植中断？
2. 乱码优先怀疑什么？教学内核是否开 MMU？
3. 从 miniOS 到通用 OS 你认为最关键的下一步？
4. 不可信技能需要的最小隔离是什么？
5. `kmalloc` 目前不做相邻空闲块合并，长时间分配/释放会有什么后果？

## 10. 提交清单

- [ ] 实验报告（PDF/Markdown）
- [ ] 关键输出摘录（含板级/QEMU 对照）
- [ ] Task5 shell 交互记录（至少 4 个内置命令的真实输出）
- [ ] 综合展示讲述稿要点
- [ ] 需要提交的代码补丁或笔记（按教师要求）

## 11. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称 |
| Ubuntu 中找不到工具 | 按 `docs/student_env_runbook.md` 安装课程工具链 |
| 板端完全无输出 | 先确认是否跑到 `_start`、加载方式、时钟配置 |
| 板端输出乱码 | 优先怀疑波特率/时钟 |
| 退不出 QEMU | `Ctrl+a`，再按 `x` |

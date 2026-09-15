# 第 7 次课实验指导书：memset/memcpy/strlen 汇编实现

> 技术编号：`07`　|　建议检查点：`07-libc-asm`（源码见 `lib/string.S`，边界测试见 `kernel/main.c`）  
> 称"第 7 次课"，不称"第 7 周"。配合讲义：`docs/07/lecture_notes.md`。  
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

完成本次课最小可验证闭环，主题：**memset/memcpy/strlen 汇编实现，以及更复杂的
memmove/strcmp/zero_and_copy**。

预期/产出：

```text
三函数注释 + 边界测试结果 + memmove 方向判断分析 + 一个自选实现的新函数
```

> 本次课不引入新知识，但也不考"能不能说出这是第几次课学的"——核心是能不能
> 独立读懂 `memmove`/`zero_and_copy` 这种真正综合运用寄存器/访存/循环/调用
> 约定的复杂代码，并能自己设计、实现一个新的、有实际意义的小功能（Task F）。

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
- 重点文件：
  - `lib/string.S`（memset/memcpy/strlen/memmove/strcmp/zero_and_copy 全部实现）
  - `include/string.h`
  - `kernel/main.c`

### 2.2 关于 `my-weekXX-lab` 分支（必读）

若本次课要求从 tag 建分支，命令形如（**在已进入的 Ubuntu 里执行**）：

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-07-lab <本次课tag>
```

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `07-libc-asm`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-07-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。  
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. 实验任务（默认均在已进入的 Ubuntu、仓库根目录）

### Task1 参数表

- 写出 `memset`/`memcpy`/`strlen` 的 `$a0/$a1/$a2` 与返回值对应。

### Task2 逐行注释

- 注释 `memset`、`memcpy`、`strlen` 的循环结构。

### Task3 边界测试

- 设计 n=0、长度1、普通字符串等用例（可用现有 main 路径或自测）。

### Task4 讨论

- 说明为何先逐字节、重叠区间为何需要 `memmove`（概念）。

### Task5 读懂 `memmove`

- 逐行注释 `lib/string.S` 里的 `memmove`，标出两条路径（正向搬 / 反向搬）
  分别在什么条件下执行。
- 自己找一组具体的重叠输入（不要照抄讲义里的例子），如果 `memmove` 不判断
  方向、永远正向搬，手工模拟一遍会得到什么错误结果；和真实运行结果对比，
  写清楚错在哪一步、为什么错。

### Task6 读懂 `zero_and_copy`

- 画出 `zero_and_copy` 三次 `bl`（memset/strlen/memcpy）前后 `$s0`/`$s1`/`$ra`
  各自的值，说明为什么必须用 `$s0`/`$s1` 而不能像 `memset`/`memcpy` 内部
  那样用 `$t0`/`$t1`。

### Task7（开放实现，本次实验重点）自选一个新函数

从下面任选一个（或自己设计一个有实际意义的小功能），独立实现在
`lib/string.S`（先在 `include/string.h` 加声明），并在 `kernel/main.c` 里
写出真实调用验收，`printk` 打印结果：

- `int strncmp(const char *a, const char *b, size_t n)`：只比较前 n 个字符。
- `const char *strchr(const char *s, int c)`：找字符 `c` 第一次出现的位置，
  找不到返回 `NULL`。
- `void str_to_upper(char *s)`：原地把小写字母转成大写（不调用别的函数）。

不要求照抄课上的写法，只要求：能讲清楚自己的实现为什么对、覆盖了哪些边界；
如果实现里调用了别的函数，能讲清楚寄存器怎么安排的（参考 `zero_and_copy`）。

### Task8 运行验收

```bash
make clean
make
make run
```

核对串口输出（`Ctrl+a` 再 `x` 退出 QEMU）：

```text
memset n=0 : buf[0]='X' (应仍为 X，未改动)
memset n=1 : buf[0]='Z' buf[1]='X' (应为 Z / X)
memcpy n=0: dst[0]='X' (应仍为 X，未改动)
memcpy n=1: dst[0]='A' dst[1]='X' (应为 A / X)
strlen ""  : len = 0 (应为 0；非空串已在第 5 次课验收)
zero_and_copy: greet="hi7"
strcmp verified: greet == "hi7"
strcmp verified: greet != "hi8"
memmove left  (dst<src): CDEFGHGH (期望 CDEFGHGH)
memmove right (dst>src): ABABCDEF (期望 ABABCDEF)
week07-libc-asm check done
```

如果完成了 Task7 的自选实现，把它的验收输出也一并贴出来（不强制加进
`kernel/main.c` 的固定验收段，可以临时加在其后，提交前可以保留）。

## 4. 验收标准

- 三个基础函数控制流正确理解
- 边界用例有记录
- 能解释 `ld.bu` 的选择
- **能讲清 `memmove` 为什么要判断方向**：能举出一个反例说明不判断会出错
- **能讲清 `zero_and_copy` 的三条寄存器时间线**，说明为什么必须用 callee-saved 寄存器
- **Task7 自选实现完成，且能独立讲清楚为什么对**（这是本次实验的核心验收点，
  不是"选做"）
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行
- `make run` 输出与上方 Task8 摘录一致

## 5. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. `memmove` 方向判断分析（Task5）
4. `zero_and_copy` 三条寄存器时间线（Task6）
5. **Task7 自选实现的代码、说明与验收输出**
6. 对核心代码/指令的简要注释或流程图
7. 问题与解决过程（若有）
8. 思考题作答

## 6. AI 共学边界

允许对照 ABI；禁止只交无讲解的长代码。Task7 的自选实现尤其如此——AI
可以帮你核对边界情况、检查寄存器约定，但代码必须是你自己想清楚再写的，
答辩时要能脱稿讲清楚每一行在做什么。

## 7. 思考题

1. `memset` 的填充值只有低 8 位有意义吗？
2. 为何返回 dst？
3. 按 8 字节优化要处理哪些对齐问题？
4. `memmove` 里如果 `dst == src`，会走哪条路径？结果对不对？
5. 如果 `zero_and_copy` 调用方传入的 `dst_size` 小于 `strlen(src)`，会发生
   什么？这算 `zero_and_copy` 的 bug，还是调用方没遵守契约？

## 8. 提交清单

- [ ] 实验报告（PDF/Markdown）
- [ ] `memmove` 方向判断分析（Task5）
- [ ] `zero_and_copy` 三条时间线注释（Task6）
- [ ] Task7 自选实现的代码 + 验收输出
- [ ] 关键输出摘录
- [ ] 需要提交的代码补丁或笔记（按教师要求）

## 9. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称；确认第 1 周已安装 Ubuntu |
| Ubuntu 里 `command not found: make` | 见 runbook 安装交叉工具链 |
| 找不到 Makefile | 检查是否已在 Ubuntu 中 `cd` 到 miniOS 根目录 |
| 退不出 QEMU | Ctrl+a 然后 x |

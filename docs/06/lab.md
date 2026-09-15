# 第 6 次课实验指导书：函数调用约定与栈帧

> 技术编号：`06`　|　建议检查点：`06-stack-abi（可逐步补齐）`  
> 称“第 6 次课”，不称“第 6 周”。配合讲义：`docs/06/lecture_notes.md`。  
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

完成本次课最小可验证闭环，主题：**函数调用约定与栈帧**。

预期/产出：

```text
完成 add3 或等价调用实验；栈帧草图
```

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
  - `boot/start.S`（`_start` 中 `bl clear_bss` / `bl kernel_main` 两次调用）
  - `lib/stack_abi.S`（本课可运行 demo：`sa_add_one`/`sa_add`/`sa_add3`/`sa_strlen_and_puts`）
  - `include/stack_abi.h`
  - `lib/string.S`（`memset`/`strlen` 的参数寄存器对照）
  - `kernel/printk.c`（`uart_puts`：C 写的非叶子函数，同样遵守 `$a0` 约定）
  - `kernel/exception.c（预告）`

### 2.2 关于 `my-weekXX-lab` 分支（必读）

若本次课要求从 tag 建分支，命令形如（**在已进入的 Ubuntu 里执行**）：

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-06-lab <本次课tag>
```

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `06-stack-abi（可逐步补齐）`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-06-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。  
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. 实验任务（默认均在已进入的 Ubuntu、仓库根目录）

### Task1 约定默写

- 写出参数寄存器、返回值寄存器、`$ra` 的来源。
- 写出 `$s0`–`$s8`/`$fp` 是 caller-saved 还是 callee-saved，`$t0`–`$t8` 呢？两者的区别用一句话说清楚。
- 说出栈帧大小为什么必须是 16 的倍数（提示：不是代码风格，是 LP64D 的硬性要求）。

### Task2 叶子 vs 非叶子

- 各举一例：是否必须保存 `$ra`，为什么。
- 对照 `strlen`（单参数、叶子）与 `uart_puts`（C 写的非叶子，内部调 `uart_putc`）：分别指出参数寄存器、是否碰 `$ra`。

### Task3 实现 add3

- 先纸笔汇编实现 `int add3(int a,int b,int c)`，再对照 `lib/stack_abi.S` 里的 `sa_add3`：它内部两次 `bl sa_add`（叶子函数 `x+y`），逐行标注栈帧的伸/存/调/取/折/返。
- 回答：为什么 `sa_add3` 必须在两次 `bl` 之前先把自己收到的 `$ra` 存进栈帧？（提示：第一次 `bl` 会覆盖 `$ra`。）

### Task3b 读 `sa_strlen_and_puts`：$s0/$s1 的存/取

- 打开 `lib/stack_abi.S` 里的 `sa_strlen_and_puts`（内部真调 `strlen` 与 `uart_puts`），逐行标注：哪两个槽位存的是 `$s0`/`$s1`，哪个槽位存的是 `$ra`；栈帧为何是 32 字节。
- 指出 `$s0` 在两次 `bl` 之间保存的是什么值、`$s1` 保存的是什么值；如果把 `move $s0, $a0` 之后紧跟的两条 `st.d $s0.. / ld.d $s0..`（入口存、出口取）删掉会发生什么？
- 对比 `sa_add3` 用栈上局部变量暂存 `c`、`sa_strlen_and_puts` 用 `$s0`/`$s1` 暂存值：两种做法都合法，分别对应第 6 次课讲的哪条规则（caller-saved 自行处理 / callee-saved 必须存取成对）？

### Task4 对照工程

- 标注 `memset` 的 `$a0/$a1/$a2`，以及 `strlen`（`lib/string.S`）只用 `$a0` 的原因。
- 标注 `uart_puts`（`kernel/printk.c`）的参数寄存器，说明它作为 C 函数为何也要遵守同一套约定。
- 解释 `_start` 中两次 `bl` 为何要求 `clear_bss` 正确返回。

### Task5 运行验收

```bash
make clean
make
make run
```

核对串口输出（`Ctrl+a` 再 `x` 退出 QEMU）：

```text
leaf  sa_add_one: 41+1 = 42
frame sa_add3 (bl x2, $ra saved): 1+2+3 = 6
frame sa_strlen_and_puts (uses $s0/$s1): data section ok -> len = 15
week06-stack-abi check done
```

## 4. 验收标准

- 栈帧伸/折成对，大小为 16 的倍数
- 非叶子函数保存并恢复 `$ra`
- 能画出 foo→bar 的 `$ra` 变化
- 能分清 caller-saved（`$t*`/`$a*`/`$ra`）与 callee-saved（`$s*`/`$fp`）的区别，并各举一例
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行
- `make run` 输出与上方 Task5 摘录一致

## 5. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 对核心代码/指令的简要注释或流程图
4. 问题与解决过程（若有）
5. 思考题作答

## 6. AI 共学边界

允许检查栈帧是否成对；`$ra` 时间线须学生口述。

## 7. 思考题

1. 漏存 `$ra` 的典型症状？
2. 栈向低地址增长时正偏移含义？
3. 若一个函数把 `c` 存进 `$s0` 而不是栈，却忘了先保存调用者的 `$s0` 原值，会出现什么症状？和漏存 `$ra` 的症状像不像？
4. `exception_entry` 为何最终是 `ertn`？（预告）

## 8. 提交清单

- [ ] 实验报告（PDF/Markdown）
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

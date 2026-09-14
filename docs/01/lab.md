# 第 1 次课实验指导书：从 0 启动 LoongArch miniOS

> 技术编号：`01`　|　建议检查点：`01-qemu-hello`  
> 称“第 1 次课”，不称“第 1 周”。配合讲义：`docs/01/lecture_notes.md`。  
> **环境总手册（强烈建议收藏）：** `docs/student_env_runbook.md`  

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

完成本次课最小可验证闭环，主题：**从 0 启动 LoongArch miniOS**。

预期/产出：

```text
Hello miniOS on LoongArch64
```

## 2. 实验环境与准备（必须先做对，否则后面全错）

### 2.0 课程默认前提

- **第 1 周已完成**：本机装好 **WSL + Ubuntu**（安装本身按课堂要求完成；本实验指导书从“进入 Ubuntu”开始写）。  
- 本实验所有 `make` / 编译 / QEMU **只在 Ubuntu 里做**。  
- 总手册：`docs/student_env_runbook.md`。

### 2.1 命令必须在哪里敲？

| 窗口提示符 | 你在哪 | 能不能敲 `make` |
|---|---|---|
| `PS D:\...>` | Windows PowerShell（还没进 Ubuntu） | **不能** |
| `C:\...>` | Windows cmd | **不能** |
| `user@xxx:~$` | **已进入 Ubuntu** | **能** |

**口诀：提示符以 `PS` 开头 = 还在 Windows = 先进入 Ubuntu，禁止敲 `make`。**

若在 PowerShell 看到 `无法将“make”项识别为 cmdlet` / `ObjectNotFound: make` / `+ ~~~~`：  
说明你**还没进入 Ubuntu**就敲了 `make`。按下面 §2.2 重来。

### 2.2 标准操作顺序：先从 WSL 进入 Ubuntu，再 make

#### 步骤 1：从 WSL 进入 Ubuntu（每次实验第一步）

**任选一种：**

**（推荐）PowerShell → WSL → Ubuntu**

1. 打开 **Windows PowerShell**（此时是 `PS ...>`，先别 make）  
2. 输入并回车：

```powershell
wsl -d Ubuntu
```

3. 等到提示符变成类似：

```text
zhangsan@DESKTOP-XXXX:~$
```

（前面**没有** `PS`，这才算进入 Ubuntu。）

**或：开始菜单**

1. 开始菜单搜索并打开 **Ubuntu**  
2. 同样等到 `用户名@主机名:~$`

**若 `wsl -d Ubuntu` 失败：** 在 PowerShell 执行 `wsl -l -v`，确认列表里有 `Ubuntu`，再用列表中的 **NAME** 作为 `-d` 参数。没有 Ubuntu 则需先补完第 1 周安装。

#### 步骤 2：在 Ubuntu 里进入仓库根目录

路径对照：`D:\foo\bar` → `/mnt/d/foo/bar`。  
示例（改成你的实际路径）：

```bash
cd "/mnt/d/日常教学/2026-2027第一学期/汇编语言/miniOS"
pwd
ls Makefile
```

能列出 `Makefile` 再继续。

#### 步骤 3：检查工具（第一次实验或换机必做）

```bash
which make
which loongarch64-linux-gnu-gcc
which qemu-system-loongarch64
```

缺失则：

```bash
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

#### 步骤 4：此后所有 git / make 都在本 Ubuntu 窗口执行

```bash
pwd
git status
```

### 2.2 重点阅读文件

- `boot/start.S`
- `kernel/main.c`
- `kernel/printk.c`
- `include/uart.h`

### 2.3 关于 `my-01-lab` 分支（必读）

| 名称 | 是什么 | 在 GitHub / `origin` 上？ |
|---|---|---|
| `01-qemu-hello` | 课程 **tag**（全班统一验收快照） | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-01-lab` | **你的本地实验分支**（名字可改） | **默认没有** |

`git switch -c my-01-lab 01-qemu-hello` 的含义是：以 tag 为起点，在**本机**新建实验分支。  
远程看不到 `my-01-lab` 是正常设计，不是漏推。  
详解：`docs/01/student_git_tag_guide.md`。

## 3. 实验任务（全部在 Ubuntu 仓库根目录完成）

### Task1 环境检查

在 Ubuntu 中执行并记录输出摘要：

```bash
which make
which loongarch64-linux-gnu-gcc
which qemu-system-loongarch64
make --version | head -1
```

### Task2 获取代码（创建本地实验分支）

```bash
git fetch --tags
git switch -c my-01-lab 01-qemu-hello
git branch
git tag | grep 01
```

自检：

- `git branch` 当前行有 `* my-01-lab`（或你自定的名字）
- 能看到 tag `01-qemu-hello`
- **不要**期望 `git branch -r` 出现 `origin/my-01-lab`

若提示分支已存在：

```bash
git switch my-01-lab
# 或换名：git switch -c my-01-lab-2 01-qemu-hello
```

### Task3 编译运行

**完整顺序（请按此抄写）：**

① 若当前还是 PowerShell（`PS ...>`），先进入 Ubuntu：

```powershell
wsl -d Ubuntu
```

② 提示符变为 `用户名@主机名:~$` 后，在 Ubuntu 中：

```bash
cd "/mnt/d/日常教学/2026-2027第一学期/汇编语言/miniOS"   # 按本机路径修改
make clean
make
make run
```

预期串口输出：

```text
Hello miniOS on LoongArch64
```

退出 QEMU：先按 **Ctrl+a**，再按 **x**。

### Task4 阅读启动路径

- 在 `boot/start.S` 标出 `_start`、设栈、调用 `kernel_main`、halt。
- 回答三问：第一条指令在哪？为何不是 main？为何不能 printf？

### Task5（选做）检查点对比

- 依次观察 `01-00-skeleton` … `01-03-printk-uart` 的输出差异。

## 4. 验收标准

- 真实运行得到一行：`Hello miniOS on LoongArch64`
- 实验报告含命令与真实输出，不得编造
- 能口述 CPU → `_start` → `kernel_main` → UART 路径
- 能说明：为何不能在 Windows PowerShell 里直接 `make`

## 5. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 对核心代码/指令的简要注释或流程图
4. 问题与解决过程（若有；含环境类问题也可写）
5. 思考题作答

## 6. AI 共学边界

仅允许解释与画图，不允许直接生成实验代码。

## 7. 思考题

1. 不设 `$sp` 可能发生什么？
2. `printk` 与用户态 `printf` 差在哪一层？
3. 为什么先 QEMU 再开发板？

## 8. 提交清单

- [ ] 实验报告（PDF/Markdown）
- [ ] 关键输出摘录
- [ ] 需要提交的代码补丁或笔记（按教师要求）

## 9. 常见故障速查

| 现象 | 原因 | 处理 |
|---|---|---|
| `ObjectNotFound: make` / `无法将 make 项识别为...` | 在 PowerShell 里敲了 `make` | `wsl -d Ubuntu`，再 `cd` 到仓库后重试 |
| `command not found: make`（在 Ubuntu 里） | 未安装工具链 | 见 §2.1 步骤 3 的 `apt install` |
| `No such file: Makefile` | 目录不对 | 检查 `pwd` 与 `/mnt/<盘符>/.../miniOS` |
| QEMU 黑屏/无输出 | 未用正确 target 或未编过 | 先 `make` 成功再 `make run` |
| 退不出 QEMU | 退出键不对 | **Ctrl+a** 然后 **x** |
| `git status` 显示一大片文件都是 `modified`（但没手动改过代码），或 `git switch` 报 `Please commit your changes or stash them` | 在 Windows PowerShell 里 `git clone`，又在 WSL 里 `git status`/`git switch`，两边换行符（CRLF/LF）设置不一致 | `git checkout -- .` 清掉这些换行符差异；以后统一在 WSL 里 `git clone`，见 `docs/01/student_git_tag_guide.md` §1 |
| `cannot open scripts/check-env.sh: No such file` | 已经 `git switch -c my-01-lab 01-qemu-hello` 切到课次 tag 之后才跑这个脚本——`01-qemu-hello` 等课次 tag 按"只保留本次课必需代码"原则不包含 `scripts/` 目录，只有 `master` 上才有 | 改用 Task1 的手动命令：`which make` / `which loongarch64-linux-gnu-gcc` / `which qemu-system-loongarch64`，效果一样、不依赖任何仓库文件；`check-env.sh` 只能在切 tag **之前**（还在 `master` 上）用 |

# 第 5 次课实验指导书：分支、循环与汇编程序设计基础

> 技术编号：`05`　|　建议检查点：`05-branch-loop（可逐步补齐）`  
> 称“第 5 次课”，不称“第 5 周”。配合讲义：`docs/05/lecture_notes.md`。  
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

完成本次课最小可验证闭环，主题：**分支、循环与汇编程序设计基础**。

预期/产出：

```text
完成 sum 与 strlen 骨架；clear_bss 流程图
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
  - `boot/start.S`（`clear_bss`：本课要画流程图的对象）
  - `lib/branch_loop.S`（本课可运行 demo：`bl_sum1n`/`bl_are_equal`/`bl_not_equal_demo`/`bl_count_nonzero`）
  - `include/branch_loop.h`
  - `lib/string.S`（`strlen`：字符串遍历骨架，第 2 次课已具备）

### 2.2 关于 `my-weekXX-lab` 分支（必读）

若本次课要求从 tag 建分支，命令形如（**在已进入的 Ubuntu 里执行**）：

```bash
git fetch --tags
git switch -c my-05-lab <本次课tag>
```

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `05-branch-loop（可逐步补齐）`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-05-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。  
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. 实验任务（默认均在已进入的 Ubuntu、仓库根目录）

### Task1 流程图

- 为 `clear_bss` 画流程图，标注条件/体/步进/退出。

### Task2 计数循环

- 先纸笔实现 `sum=1..n`（n 在 `$a0`，和返回 `$a0`），再对照 `lib/branch_loop.S` 里的 `bl_sum1n`，逐行标注条件/体/步进。

### Task3 字符串骨架 + if-else 对照

- 写出 `strlen` 控制流骨架（`ld.bu` + `beqz` + 指针++），对照 `lib/string.S` 的 `strlen` 实现。
- 阅读 `bl_are_equal`（`beq` 版）与 `bl_not_equal_demo`（`bne` 版），说明二者为何等价。
- 阅读 `bl_count_nonzero`，指出它与 `while` 模板相比多了什么角色（下标/越界判断）。

### Task4 找错

- 说明“忘记更新计数/游标”为何导致死循环。

### Task5 运行验收

```bash
make clean
make
make run
```

核对串口输出（`Ctrl+a` 再 `x` 退出 QEMU）：

```text
loop  while sum: 1+..+5 = 15
branch beq  : (3==3) = 1
branch bne  : (3==4) = 0
loop  bnez count nonzero {0,3,0,7,9} = 3
loop  strlen(data_message) = 15
week05-branch-loop check done
```

## 4. 验收标准

- while 模板使用正确
- 字符串遍历能处理空串
- 五问检查单有书面记录
- `make run` 输出与上方 Task5 摘录一致
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行

## 5. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 对核心代码/指令的简要注释或流程图
4. 问题与解决过程（若有）
5. 思考题作答

## 6. AI 共学边界

允许检查流程图；最终汇编须学生能讲解。

## 7. 思考题

1. 空字符串循环体执行几次？
2. `b` 与 `bl` 混用的后果？
3. 编译器翻译 `for` 时常见落点指令？

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

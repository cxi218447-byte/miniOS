# Git 极简入门（零基础版）

这份文档写给**完全没用过 Git** 的同学，只讲这门课用得到的最少命令，讲清楚
"为什么"，不讲用不到的东西。想看更详细的"第 1 次课怎么选版本"操作清单，
看 [`01/student_git_tag_guide.md`](01/student_git_tag_guide.md)，这份是给
第一次接触 Git 的人先建立整体概念用的。

## Git 是什么，为什么这门课要用它

Git 是一个"版本管理工具"，简单理解成：它能把一个项目的每一个历史版本都
存下来，你可以随时切换到任意一个版本，互不干扰。

这门课**每次课的代码是一个独立版本**（12 次课 = 12 个版本），全部存在同
一个仓库里。你不用每次课都找老师要一份新代码——用 Git 命令"切换"到对应
版本就行，仓库里其实什么都有，只是平时只显示你当前所在这一个版本的内容。

## 4 个必须先搞懂的名词

不用死记，跟着后面的操作走一遍就明白了，这里先混个眼熟：

| 名词 | 大白话理解 |
|---|---|
| **仓库（repo）** | 存着这门课全部代码和历史版本的一个文件夹 |
| **克隆（clone）** | 把远程（GitHub 上）的仓库整个拷贝一份到你自己电脑上 |
| **标签（tag）** | 老师给每次课的代码打的"版本编号"，比如 `01-qemu-hello` 就是第 1 次课的版本 |
| **分支（branch）** | 你在本地"复印"出来、可以自己随便改的一份代码，改坏了也不影响原始版本 |

## 第一次用：克隆仓库

**在 WSL Ubuntu 终端里**执行（不要在 Windows PowerShell 里做，原因见下面
"常见坑"第一条）：

```bash
git clone https://github.com/cxi218447-byte/miniOS.git
cd miniOS
```

这一步只做一次。执行完，`miniOS` 这个文件夹里就有这门课**全部 12 次课**
的历史版本了（虽然此刻你只看得到最新的那个版本，其他版本要用下一步的
命令"切换"过去才能看到）。

**想放到指定的新位置？** 先 `cd` 到你想存放的父目录，再在 `clone` 命令
末尾加上目标路径（不加则默认用仓库名 `miniOS` 建在当前目录）：

```bash
git clone https://github.com/cxi218447-byte/miniOS.git "/mnt/d/你的路径/miniOS"
```

**GitHub 打不开（校园网常见）？** 换成 Gitee 镜像地址再 clone 一次，其余
命令完全不变、内容与 GitHub 保持同步：

```bash
git clone https://gitee.com/cxi218447-bytes/miniOS.git
cd miniOS
```

更完整的说明（含已克隆过想切换到 Gitee 的做法）见
`docs/student_env_runbook.md` §3。

## 每次上课都要做：切换到本次课的版本

两条命令，先拉一下老师最新发布的版本标签，再切过去：

```bash
git fetch --tags
git switch -c my-01-lab 01-qemu-hello
```

拆开讲这两条在做什么：

- `git fetch --tags`：去 GitHub 上看一眼老师有没有发布新的课次标签，同步到
  你本地。每次上课前先跑一遍，保证你本地知道的标签是最新的。
- `git switch -c my-01-lab 01-qemu-hello`：意思是"以 `01-qemu-hello` 这个
  标签（第 1 次课的版本）为起点，给我复印一份到一个叫 `my-01-lab` 的新分支
  上"。`-c` 就是"create"（新建）的意思。**这份复印件是你自己的**，你在
  上面随便改、随便实验都不会影响原始的 `01-qemu-hello` 标签。

以后每次课，把命令里的数字和标签名换成对应那次课的就行（标签名在
`README.md` 的课次列表里能查到），比如第 2 次课：

```bash
git switch -c my-02-lab 02-data-bss
```

**分支名 `my-01-lab`、`my-02-lab` 你可以自己随便起**，只是数字/名字对上
第几次课方便自己记，不是固定要求。

## 平时用得上的 3 条命令

```bash
git status          # 看当前有没有改动过还没处理的文件
git branch          # 看现在有哪些本地分支，当前所在的前面有个 *
git log --oneline -5   # 看最近几条历史记录，确认自己在哪个版本
```

这三条随时执行都不会改动任何代码，纯粹是"看一眼现状"，放心用。

## 这门课**不需要**你做的事

- **不需要 `git add` / `git commit` / `git push`**。这门课是你在本地改代码、
  本地编译、本地用 QEMU 跑，不需要把你的实验代码提交回 GitHub。
- **不需要给自己的分支 `my-01-lab` 之类 push 到远程**——它本来就只存在于
  你自己电脑上，GitHub 网页上看不到是正常的，不是你操作漏了什么。
- 如果你确实想学 `commit`/`push` 这些协作开发用的命令（比如以后做别的项目
  要跟同学一起写代码），那是另一套更大的知识，这门课用不上，先不用管。

## 常见坑

### 1. 一定要在 WSL 里 `clone`，不要在 Windows PowerShell 里

Windows 的 Git 默认会把代码里的换行符转换成 Windows 格式（`CRLF`），WSL
里的 Git 认的是 Linux 格式（`LF`）。两边混用的话，`git status` 会显示
**几乎每个文件都被改过**（其实内容一个字都没变，只是换行符不一致），严重
的时候切分支会报错
`Please commit your changes or stash them before you switch branches`。
统一在 WSL 终端里操作能从根上避免这个问题。

如果已经在 PowerShell 里 clone 过了，先别慌，进 WSL 之后按下面路径转换
规则接着用（盘符换小写、去掉冒号）：

```bash
wsl -d Ubuntu
cd "/mnt/<盘符>/<你的课程工作目录>/miniOS"
```

如果这时候 `git status` 真的显示一大片 `modified`，先确认自己没有真的
手动改过代码，再执行：

```bash
git checkout -- .
```

把这些换行符差异清掉，`git status` 变回 `nothing to commit, working tree
clean` 就正常了。

### 2. `git switch -c my-01-lab 01-qemu-hello` 报错说分支已存在

说明这个分支名你之前建过了，两种办法选一种：

```bash
git switch -c my-01-lab-2 01-qemu-hello    # 换个名字重新建一个
```

```bash
git switch my-01-lab                       # 或者直接切回原来那个
```

### 3. `git switch -c` 报错说找不到这个 tag

先确认拼写跟 `README.md` 里写的一模一样（区分大小写），再补一次：

```bash
git fetch --tags
```

还是找不到的话，大概率是这次课的 tag 老师还没发布，等课上通知。

### 4. 忘了自己现在在哪个版本

```bash
git branch
```

前面带 `*` 的那一行就是你当前所在的分支。

## 之后想看更完整的说明

- 具体每次课的操作细节、tag 含义对照表：`docs/01/student_git_tag_guide.md`
  （目前详细写了第 1 次课，可以按同样的思路类推到其他课次）
- 环境装不上（WSL/工具链相关）：`docs/manual_wsl_ubuntu22_toolchain_build.md`
  或 `docs/manual_wsl_ubuntu26_install.md`

# 第 1 次课 Git 版本选择操作清单

本清单用于帮助同学从课程仓库中选择指定的第 1 次课实验版本，并在该版本基础上开始自己的实验。

> **与环境的关系：** `git` 可在 Windows 或 WSL 中使用，但随后的 **`make` / QEMU 必须在 WSL Ubuntu（或 Linux）中执行**。  
> 若你在 PowerShell 看到 `ObjectNotFound: make`，先读 `docs/student_env_runbook.md`，不要在 Windows 里死磕 `make`。

## 1. 首次克隆仓库

**建议统一在 WSL Ubuntu 里执行 `git clone`**，不要在 Windows PowerShell 里
clone。原因：Windows 的 git 默认会把换行符转成 `CRLF` 写到磁盘上，WSL 的
git 按 `LF` 比较文件——如果克隆和之后的 `git status`/`git switch` 分别用了
两边不同的 git，会出现**几乎每个文件都显示"modified"**（其实内容一个字节
没变，只是换行符不一致），干扰后面切分支（甚至直接报错
`Please commit your changes or stash them before you switch branches`）。
统一在 WSL 里操作可以从根上避免这个问题。

```bash
git clone https://github.com/cxi218447-byte/miniOS.git
cd miniOS
```

**想放到指定的新位置？** 先 `cd` 到目标父目录，或直接在命令末尾加路径：

```bash
git clone https://github.com/cxi218447-byte/miniOS.git "/mnt/d/你的路径/miniOS"
```

**GitHub 打不开（校园网常见）？** 换 Gitee 镜像地址，内容与 GitHub 同步：

```bash
git clone https://gitee.com/cxi218447-bytes/miniOS.git
cd miniOS
```

已经用 GitHub 地址克隆过、想改连 Gitee 的话不用重新克隆，改远程地址即可：

```bash
git remote set-url origin https://gitee.com/cxi218447-bytes/miniOS.git
```

更完整说明见 `docs/student_env_runbook.md` §3。

如果你确实在 Windows PowerShell 里克隆过（比如已经这样做了），编译前
`cd` 进 WSL 时留意路径转换：

```powershell
wsl -d Ubuntu
cd "/mnt/<盘符>/.../miniOS"    # 把 Windows 路径换成 /mnt/...
```

**如果这时候 `git status` 发现一大片文件都是 `modified`**：先确认没有
真的动过代码，再执行 `git checkout -- .` 把这些换行符差异清掉，
`git status` 变回 `nothing to commit, working tree clean` 后再继续。

## 2. 获取所有课程版本标签

```bash
git fetch --tags
git tag
```

执行后会看到**全部 12 次课**的 tag（因为课程仓库只维护一份 `master` +
全部课次 tag，不是每次课单独一个仓库），类似：

```text
01-00-skeleton
01-01-stack-setup
01-02-kernel-main-empty
01-03-printk-uart
01-qemu-hello
02-data-bss
03-regs-alu
04-load-store
05-branch-loop
06-stack-abi
07-libc-asm
08-uart-syscall
09-trap-irq
10-build-debug
11-irq-kernel-recap
12-board-agent-demo
```

**第 1 次课只用得上前 5 个（`01-` 开头的）**，后面 `02-`…`12-` 是后续
课次的验收点，本次课不用管、也不要提前切过去看——课程原则是"按 tag
取代码，不提前混入后续课次内容"，详见各 tag 含义见下方 §4。

推荐**不要直接在 tag 上修改代码**，而是从 tag 新建自己的实验分支。

例如从第 1 次课完整版本开始：

```bash
git switch -c my-01-lab 01-qemu-hello
```

如果老师要求从最小骨架开始：

```bash
git switch -c my-01-lab 01-00-skeleton
```

### 3.1 为什么要建 `my-01-lab`？它为什么不在远程？

这是最容易误解的一点，请务必读完。

| 名称 | 角色 | 谁创建 | 是否出现在 GitHub |
|---|---|---|---|
| `01-qemu-hello` 等 | **课程 tag**（全班统一的验收快照） | 老师发布 | **是** |
| `master` | 当前已发布课次进度 | 老师维护 | **是** |
| `my-01-lab` | **你的本地作业本** | **你自己**用 `-c` 创建 | **默认否** |

- `git switch -c 新分支名 起点tag` =「从课程固定版本复印一份到我电脑上，方便我改」  
- 所以 `my-01-lab` **本来就只在本地**；远程没有这个分支名是**设计如此**，不是操作失败  
- 课程仓库远程只需要：`master` + 各课次 tag；**不会**为每个同学建 `my-weekXX-lab`  
- **一般不要** `git push -u origin my-01-lab` 到公共课程仓库  

类比：tag 像图书馆里的标准教材；`my-01-lab` 像你自己的草稿本——草稿本不会印在图书馆目录里。

### 3.2 怎么确认自己做对了？

```bash
git branch          # 当前分支前有 *，例如 * my-01-lab
git tag             # 能看到 01-qemu-hello
git branch -r       # 远程通常只有 origin/master 等，没有 origin/my-01-lab
```

## 4. 各 tag 含义（只列第 1 次课相关的）

`git tag` 会看到仓库里全部 12 次课的 tag（见 §2），但**第 1 次课只跟下面
这 5 个有关**，`02-`…`12-` 开头的是后续课次，本次课不用管：

| tag | 含义 |
|---|---|
| `01-00-skeleton` | 最初骨架：只有 `_start`，原地 halt，还没设栈、没输出 |
| `01-01-stack-setup` | 启动阶段设置 `$sp` |
| `01-02-kernel-main-empty` | 从汇编入口 `bl` 跳转到空的 `kernel_main` |
| `01-03-printk-uart` | 加上 `printk` + UART，能输出 Hello |
| `01-qemu-hello` | **第 1 次课正式验收点**，内容跟 `01-03-printk-uart` 相同 |

日常实验用最后这个 `01-qemu-hello` 就够了；前面 4 个是 §「Task5（选做）
检查点对比」里对比"骨架到能输出 Hello 逐步演进"用的，不是必须都跑一遍。

## 5. 编译和运行

进入自己的实验分支后执行：

```bash
make clean
make
make run
```

第 1 次课完整版本的预期输出：

```text
Hello miniOS on LoongArch64
```

## 6. 查看当前所在版本

```bash
git branch
git log --oneline -1
```

如果当前分支名前有 `*`，说明你正在该分支上。

## 7. 常见问题

### 问题 1：`git switch -c my-01-lab 01-qemu-hello` 报错

先更新 tag：

```bash
git fetch --tags
```

然后重新执行：

```bash
git switch -c my-01-lab 01-qemu-hello
```

### 问题 2：提示分支 `my-01-lab` 已存在

换一个分支名：

```bash
git switch -c my-01-lab-2 01-qemu-hello
```

或者切换回已有分支：

```bash
git switch my-01-lab
```

### 问题 3：为什么 GitHub 上没有 `my-01-lab` / `my-02-lab`？

因为它们是**本地实验分支**，从来不是课程远程的一部分。  
远程应有的是 tag（如 `01-qemu-hello`、`02-data-bss`）和 `master`。  
用网页打开仓库看不到 `my-weekXX-lab` 是正常现象。

### 问题 4：不小心直接 checkout 到 tag

如果执行过：

```bash
git checkout 01-qemu-hello
```

可以再创建自己的实验分支：

```bash
git switch -c my-01-lab
```

### 问题 5：做完实验如何清理本地分支？

```bash
git switch master
git branch -d my-01-lab    # 已合并可用 -d；未合并且确定不要用 -D
```

不删除也没关系，只是本机多一个分支名。

## 8. 回到主分支

```bash
git switch master
git pull
git fetch --tags
```

主分支用于获取老师后续发布的最新课程内容；实验修改建议保存在自己的实验分支中。

## 课次纯净说明

第 1 次课各 tag **不包含** 后续课次代码（无 `clear_bss`、无 `lib/string.S`、无异常/系统调用）。
请始终从对应 tag 建分支，不要在混有后续内容的树上做早期实验。

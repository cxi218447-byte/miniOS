# 学生实验运行手册（从 WSL 进入 Ubuntu 再 make）

## 0. 课程默认前提

- **第 1 周已完成**：Windows 上安装好 **WSL**，并装好发行版 **Ubuntu**（具体安装步骤见课堂/安装文档，本手册不再重复安装）。
- **本手册默认你已经能打开 Ubuntu**，只教：如何进入 Ubuntu → 进入仓库 → `make`。
- **所有 `make` / 交叉编译 / `qemu` 必须在 Ubuntu 里做**，不能在 Windows PowerShell 里直接敲 `make`。

## 1. 先认准你在哪个窗口

| 窗口提示符长什么样 | 你在哪 | 能不能敲 `make` |
|---|---|---|
| `PS D:\...>` | Windows PowerShell | **不能** |
| `C:\...>` | Windows cmd | **不能** |
| `username@主机名:~$` | **已进入 Ubuntu** | **能** |
| `username@主机名:/mnt/d/...$` | **已进入 Ubuntu，且可能已在某目录** | **能** |

**口诀：提示符以 `PS` 开头 = 还在 Windows = 先进入 Ubuntu，不要敲 make。**

## 2. 从 WSL 进入 Ubuntu（每次做实验的第一步）

下面三种方式**任选其一**。成功后提示符应变为 `用户名@计算机名:~$` 这类形式（**没有**前面的 `PS`）。

### 方式 A：开始菜单（最不容易错）

1. 按 Windows 键，搜索 **Ubuntu**  
2. 打开名为 **Ubuntu** 的应用（不要只开 PowerShell）  
3. 等到出现 Linux 提示符，例如：

```text
zhangsan@DESKTOP-ABC123:~$
```

### 方式 B：在 PowerShell 里用 WSL 进入 Ubuntu（常用）

1. 先打开 **Windows PowerShell**（此时提示符是 `PS ...>`，还不能 make）  
2. **只输入**下面这一行并回车：

```powershell
wsl -d Ubuntu
```

3. 成功后，提示符从 `PS ...>` **变成** `用户名@主机名:~$`  
4. 这时你才算“进了 Ubuntu”，后面的 `cd` / `make` 都在这个窗口继续敲  

含义简要说明：

- `wsl`：调用 Windows 的 WSL 子系统  
- `-d Ubuntu`：指定进入发行版 **Ubuntu**（第 1 周装的那个名字；若你安装时用了别的名字，把 `Ubuntu` 改成实际名字）

### 方式 C：确认本机有哪些 Linux 发行版

若 `wsl -d Ubuntu` 报错找不到发行版，在 **PowerShell** 中查看：

```powershell
wsl -l -v
```

示例输出：

```text
  NAME            STATE           VERSION
* Ubuntu          Stopped         2
  docker-desktop  Stopped         2
```

- 表里应有 **Ubuntu**（或你安装时的名字）  
- 进入时用：`wsl -d 列表里的NAME`  
- 若列表里完全没有 Ubuntu，说明第 1 周安装未完成，需先补装（见课堂安装文档），不要继续 make

### 进入成功 / 失败对照

| 现象 | 含义 | 下一步 |
|---|---|---|
| 提示符变成 `user@host:~$` | 已进入 Ubuntu | 做第 3 节：`cd` 仓库 |
| 仍是 `PS ...>` | 还在 Windows | 重做方式 A 或 B |
| `假若没有适用于所提供参数的分发` / 找不到 Ubuntu | 发行版名不对或未安装 | `wsl -l -v` 核对名字；必要时补装 |
| 一直停在安装/初始化 | 首次启动未完成 | 按提示设用户名密码，完成后再进 |

## 3. 首次克隆仓库到本地（含指定新位置 / GitHub 打不开就用 Gitee）

**只需做一次**（换新电脑，或想把仓库放到别的目录，才需要重新克隆）。
以下命令一律在 **Ubuntu** 提示符下输入，不要在 Windows PowerShell 里 `clone`
——原因见下方"为什么必须在 Ubuntu 里 clone"。

### 3.1 默认克隆（放到当前目录下）

先 `cd` 到你想存放仓库的**父目录**（例如先进你自己的工作目录），再执行：

```bash
git clone https://github.com/cxi218447-byte/miniOS.git
cd miniOS
```

执行完，当前目录下会新建一个 `miniOS` 文件夹，里面是完整仓库（含全部课次的
tag，见 `docs/student_git_basics.md`）。

### 3.2 克隆到指定的新位置

`git clone` 命令末尾可以再加一个参数，指定目标文件夹的路径和名字，不加则
默认用仓库名 `miniOS` 建在当前目录下。两种常见写法：

```bash
# ① 克隆到当前目录下，但改用自己起的文件夹名
git clone https://github.com/cxi218447-byte/miniOS.git my-miniOS

# ② 克隆到一个指定的绝对路径（目录若不存在会自动创建）
git clone https://github.com/cxi218447-byte/miniOS.git "/mnt/d/日常教学/miniOS"
```

克隆完成后，以后每次做实验都用 `cd` 进这个你指定的路径即可，跟 §4 的
`cd` 步骤是同一件事，只是把路径换成你自己实际选的那个。

**如果之前已经克隆过一份、现在想换到新位置**：不需要删掉旧的，直接对新
路径重新 `git clone` 一份即可（两份是完全独立的本地副本，互不影响）；也
可以先删掉旧文件夹（确认里面没有未保存的实验代码）再重新克隆。

### 3.3 GitHub 打不开？换 Gitee 镜像

如果 `git clone https://github.com/...` 卡住不动或直接报错（校园网/宿舍网
访问 GitHub 不稳定是常见情况），把地址换成 **Gitee 镜像仓库**再试一次，
其余命令、tag 名、分支操作完全不变：

```bash
git clone https://gitee.com/cxi218447-bytes/miniOS.git
cd miniOS
```

Gitee 上的内容与 GitHub 保持同步（同一份代码、同一套 tag）。以后 `git fetch
--tags` 等命令会默认对着你克隆时用的那个地址（GitHub 或 Gitee）去拉取，两
边二选一即可，不需要都配置。

**若已经用 GitHub 地址克隆过，后来想切换到 Gitee**（比如网络变得连不上
GitHub 了），可以改这份本地仓库的远程地址，不用重新克隆：

```bash
git remote set-url origin https://gitee.com/cxi218447-bytes/miniOS.git
git remote -v      # 确认已改成 gitee.com
git fetch --tags
```

### 3.4 为什么必须在 Ubuntu 里 clone，不能在 Windows PowerShell 里

Windows 的 Git 默认会把代码里的换行符转换成 `CRLF`，WSL 里的 Git 认的是
`LF`。两边混用会导致 `git status` 显示**几乎每个文件都被改过**（其实内容
一字没变，只是换行符不一致），严重时切分支会报错 `Please commit your
changes or stash them before you switch branches`。统一在 WSL Ubuntu 终端
里 `clone` + 之后所有操作，能从根上避免这个问题。

如果已经在 PowerShell 里 clone 过了：先别删，进 WSL 后按路径转换规则接着
用（`D:\foo` → `/mnt/d/foo`，见 §4），如果这时候 `git status` 显示一大片
`modified`，先确认没有真的手动改过代码，再执行 `git checkout -- .` 把这
些换行符差异清掉即可。

## 4. 进入课程仓库（在 Ubuntu 里）

**以下命令一律在 Ubuntu 提示符下输入**（不是 `PS`）。已经按 §3 完成首次
克隆的话，这一步只是每次实验用 `cd` 进入你存放仓库的那个目录。

Windows 路径示例：

```text
D:\日常教学\2026-2027第一学期\汇编语言\miniOS
```

在 Ubuntu 中对应：

```bash
cd "/mnt/d/日常教学/2026-2027第一学期/汇编语言/miniOS"
pwd
ls Makefile
```

路径规则：

- `D:\foo\bar` → `/mnt/d/foo/bar`  
- 盘符改成小写，`\` 改成 `/`  
- 路径有中文或空格时，请用双引号包住  

`ls Makefile` 能看到文件，说明目录正确。

## 5. 检查编译工具（第 1 次课或换机器时做一次）

仍在 **Ubuntu** 里：

```bash
which make
which loongarch64-linux-gnu-gcc
which qemu-system-loongarch64
```

三条都应打印路径。若 `command not found`：

```bash
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

**如果这条 `apt install` 报 `Unable to locate package gcc-loongarch64-linux-gnu` /
`binutils-loongarch64-linux-gnu`**：不是操作错了，是 Ubuntu 22.04 官方源里本来
就没有这两个包。两条补救路线选一条走：

- [`manual_wsl_ubuntu26_install.md`](manual_wsl_ubuntu26_install.md)：改装
  Ubuntu 26.04（跟现有 22.04 并列共存，不用卸载旧的），仓库里已经有这两个包，
  最省事。
- [`manual_wsl_ubuntu22_toolchain_build.md`](manual_wsl_ubuntu22_toolchain_build.md)：
  留在现有 22.04 上，自己装预编译工具链 + 编译 QEMU。

## 6. 检出本次课代码 + 编译运行（标准闭环）

```bash
git fetch --tags
git switch -c my-weekXX-lab <本次课tag>    # 分支名按实验指导书
git branch

make clean
make
make run
```

退出 QEMU：先按 **Ctrl+a**，再按 **x**。

关于 `my-weekXX-lab` 只在本地、远程没有的问题：见 `docs/week01/student_git_tag_guide.md`。

## 7. 完整抄写示例（第 2 次课）

下面是一段可对照的完整流程（路径请改成你的）：

**① PowerShell 中（此时还是 `PS ...>`）：**

```powershell
wsl -d Ubuntu
```

**② 进入 Ubuntu 后（提示符已是 `...$`）：**

```bash
cd "/mnt/d/日常教学/2026-2027第一学期/汇编语言/miniOS"
ls Makefile
git fetch --tags
git switch -c my-week02-lab week02-data-bss
make clean
make
make run
```

**不要**在步骤 ① 的 PowerShell 里直接敲 `make clean`。

## 8. 若你在 PowerShell 里看到 make 报错

```text
make : 无法将“make”项识别为 cmdlet、函数、脚本文件或可运行程序的名称
CategoryInfo          : ObjectNotFound: (make:String) [], CommandNotFoundException
+ make clean
+ ~~~~
```

| 原因 | 处理 |
|---|---|
| 还在 Windows，没进 Ubuntu | 先执行 `wsl -d Ubuntu`，再 `cd` 仓库，再 `make` |

## 9. 做实验前 30 秒自检

- [ ] 提示符**不是** `PS ...>`，而是 `用户名@主机名:...$`  
- [ ] 是用 `wsl -d Ubuntu` 或开始菜单 Ubuntu 进来的  
- [ ] `pwd` 在 miniOS 根目录，且存在 `Makefile`  
- [ ] `which make` 有输出  
- [ ] 当前是本次课实验分支  
- [ ] 然后才 `make clean && make && make run`  

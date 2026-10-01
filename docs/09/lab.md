# 第 9 次课实验指导书：异常与中断处理

> 技术编号：`09`　|　建议检查点：`09-trap-irq`  
> **学生自学教材：** `docs/09/week09_教材_修改版.md`——建议先读教材 §2（`exception_entry` 逐行精读）、§3（`era + 4` 踩坑）再做下面的 Task1/Task2，卡壳时按 Task 里标注的教材节号去查对应讲解。  
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

完成本次课最小可验证闭环，主题：**异常处理**。

本次实验共 **2 个任务**：

1. **Task1（跟着做）**：给出完整代码，照着抄进 `kernel/exception.c` 和 `kernel/main.c`，让
   `exception_handler` 能区分出两种不同的同步异常（`break` 触发的 BRK、非法指令触发的
   INE），跑起来看到两条不同的诊断输出；再亲手做一次 `era + 4` 踩坑实验。
2. **Task2（进阶）**：只给规格不给代码——自己在 Task1 的基础上扩充判断分支，再新增第三
   种异常来源（`syscall` 指令），当堂调试通过、截图。

**提交需要两样东西**：① Task2 里自己写的 `exception_handler` 完整代码（贴纯文本即可）；
② 验证成功后的串口输出截图。不用交完整代码补丁、不用交报告、不留思考题。

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
- 重点文件（已有，本次课要修改）：
  - `boot/start.S`（`exception_entry`，只读不改）
  - `kernel/exception.c`（`exception_init`/`exception_handler`，**本课要改**）
  - `kernel/main.c`（`kernel_main`，**本课要改**：新增异常触发点）
  - `include/exception.h`

### 2.2 关于 `my-weekXX-lab` 分支（必读）

若本次课要求从 tag 建分支，命令形如（**在已进入的 Ubuntu 里执行**）：

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-09-lab 09-trap-irq
```

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `09-trap-irq`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-09-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. 实验任务（默认均在已进入的 Ubuntu、仓库根目录）

**背景知识（两个任务都要用到）**：`exception_handler(estat, era)` 的第一个参数
`ESTAT` 里有一个 **Ecode 字段**（第 21–16 位，共 6 位），标识"这次异常具体是哪一种"——
教材 §2.2 已经提过一次（`break` 触发的异常 `Ecode=0xC`），本次课要求你实际把这个字段
从 `estat` 里"抠"出来判断，而不是只在打印时肉眼看十六进制猜。取法：

```c
unsigned long ecode = (estat >> 16) & 0x3f;
```

`>> 16` 把第 16 位移到最低位，`& 0x3f`（6 个 1）只保留这 6 位、盖掉其余无关位——
和第 8 次课 Task1 进阶部分 `uart_putc_robust` 里"读 → 只留需要的那几位"是同一套
思路，只是这次不是从内存读寄存器，而是从已经读进来的 `estat` 参数里挑位。

### Task1（跟着做）：区分 BRK 与"未识别"异常 + 亲手踩一次 `era + 4` 的坑

#### 步骤 1：改 `kernel/exception.c`，让 `exception_handler` 能报出 Ecode

把 `exception_handler` 替换成下面这段完整代码（`exception_init` 不用改，保留原样）：

```c
unsigned long exception_handler(unsigned long estat, unsigned long era)
{
    /* Ecode：ESTAT 的 bit[21:16]，标识"这次异常具体是哪一种"。
     * 编号以实测/讲义为准：0xC 是 break 触发的 BRK。 */
    unsigned long ecode = (estat >> 16) & 0x3f;

    printk("[exception] ESTAT=0x");
    printk_hex(estat);
    printk(" ERA=0x");
    printk_hex(era);
    printk(" Ecode=0x");
    printk_hex(ecode);

    if (ecode == 0xc) {
        printk(" (BRK)\n");
    } else {
        printk(" (unrecognized)\n");
    }

    /* break/syscall 是精确异常，ERA 指向触发指令本身，必须 +4 跳过它，
     * 否则 ertn 后原地再次触发，见教材 §3。 */
    return era + 4;
}
```

#### 步骤 2：改 `kernel/main.c`，新增第二种异常触发

找到现有的这两行（`break` 演示）：

```c
    __asm__ volatile("break 0");
    printk("resumed after break: ertn returned control here\n");
```

在它们**后面**紧接着加上：

```c
    /* 触发第二种异常——非法指令（全 0 不是合法的 LoongArch 指令编码）。
     * 用来验证 exception_handler 能识别出"这不是 BRK"。 */
    __asm__ volatile(".word 0");
    printk("resumed after illegal instruction\n");
```

同时把最后一行验收打印的周次前缀改对（如果你的本地代码还是旧的 `week10-...`，
改成）：

```c
    printk("week09-trap-irq check done\n");
```

#### 步骤 3：编译运行，确认两条诊断都出现

```bash
make clean
make
make run
```

应看到（`ERA` 的具体数值会随编译结果小幅变化，属正常现象；`ESTAT`/`Ecode` 应保持稳定）：

```text
exception_init: EENTRY set to exception_entry
[exception] ESTAT=0xc0000 ERA=0x200798 Ecode=0xc (BRK)
resumed after break: ertn returned control here
[exception] ESTAT=0xd0000 ERA=0x2007a4 Ecode=0xd (unrecognized)
resumed after illegal instruction
week09-trap-irq check done
```

第二条 `Ecode=0xd` 目前被判成 `(unrecognized)`——这是故意的，Task2 要求你把它也
认出来。（Ctrl+a 再 x 退出 QEMU。）

#### 步骤 4：亲手踩一次 `era + 4` 的坑（教材 §3.3）

1. 把 `return era + 4;` 临时改成 `return era;`，重新 `make run`。
2. **只需看第一条 `break` 诊断反复刷屏就够了**——串口会陷入
   "触发异常 → 打印 → ertn 回到 break 指令本身 → 再次触发"的死循环，
   永远走不到后面非法指令那一步。Ctrl+a 再 x 强制退出 QEMU。
3. 改回 `return era + 4;`，重新 `make run`，确认恢复正常（两条诊断都出现，
   打印到 `week09-trap-irq check done` 后停住）。

### Task2（进阶，当堂调试 + 截图）：识别 INE，并新增第三种异常来源

**要求**：在 Task1 的基础上（不给代码，只给规格）：

1. **认出非法指令异常**：把 Task1 步骤 3 里观察到的 `Ecode=0xd` 也加进判断分支，
   打印一个你自己起的名字（比如 `"INE"`），不能再停留在 `(unrecognized)`。
2. **新增第三种触发**：在 `kernel_main` 里、非法指令 demo **之后**，用内联汇编执行一条
   `syscall 0` 指令（写法参考步骤 2 里 `.word 0` 的接线方式，指令换成
   `__asm__ volatile("syscall 0");`，后面配一行 `printk` 确认恢复执行）。
   `syscall` 指令触发的是 CPU 硬件级别的 SYS 异常——跟第 9 次课之前
   `syscall_dispatch()` 那种"直接调用 C 函数"的软件分发方式完全是两回事，
   这里是让 CPU 真的走一次异常入口。
3. **认出 SYS 异常**：运行一次，观察 `syscall 0` 对应的 Ecode 是多少（不要凭空套用
   BRK/INE 的数字），把它也加进判断分支，打印你自己起的名字（比如 `"SYS"`）。
4. 最终 `exception_handler` 要能对三种异常各自打印出**不同、正确**的名字，不允许出现
   `(unrecognized)`；整机不能卡死，能正常打印到 `week09-trap-irq check done`。

**验收**：

```bash
make clean && make && make run
```

三条 `[exception]` 诊断行都要出现，且分别标注为你自己起的三个不同名字，最后仍
以 `week09-trap-irq check done` 收尾（Ctrl+a 再 x 退出 QEMU）。

调通之后，提交下面两样东西：

**代码：请提交你 Task2 改完后的完整 `exception_handler` 函数代码**

把 `kernel/exception.c` 里 `exception_handler` 这一段原样贴在下面的文本框里（纯文本即可，不用上传图片）。

**截图：贴出串口从 `exception_init: EENTRY set to exception_entry` 到 `week09-trap-irq check done` 的完整输出截图**

证明三种异常都被正确识别，这是本次要交的截图。

## 4. 验收标准

- `exception_handler` 能从 `ESTAT` 里正确抠出 Ecode 字段（`(estat >> 16) & 0x3f`），
  不是靠肉眼看打印猜测。
- 三种异常（`break`/非法指令/`syscall`）各自打印出正确、不同的诊断名字，不允许
  `(unrecognized)` 残留。
- 亲手验证过 `era + 4` 踩坑：能说明去掉 `+ 4` 为什么会死循环（教材 §3）。
- 整机运行不卡死、不崩溃，串口从 `exception_init: ...` 完整打印到
  `week09-trap-irq check done`。
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行。

## 5. 报告要求

本次实验不要求提交单独的实验报告；学生提交的"报告正文"就是 Task2 里贴的
`exception_handler` 函数代码文本本身。批改时对照上面的验收标准逐条核对这段
代码和配套截图即可，不需要额外的文字说明。

## 6. 验收与提交

- Task1：两种异常（BRK/非法指令）诊断均正确打印，`era + 4` 踩坑现象亲手观察过。
- Task2：三种异常（BRK/INE/SYS）诊断均正确打印，无 `(unrecognized)` 残留（1 张截图）。
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行。

**提交清单**：

- [ ] Task2 改完后的完整 `exception_handler` 函数代码（纯文本）
- [ ] Task2 验收截图（三种异常都被正确识别的完整串口输出）

不用交代码补丁、不用写报告、不留思考题。

## 7. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称；确认第 1 周已安装 Ubuntu |
| Ubuntu 里 `command not found: make` | 见 runbook 安装交叉工具链 |
| 找不到 Makefile | 检查是否已在 Ubuntu 中 `cd` 到 miniOS 根目录 |
| 加了非法指令/`syscall` 后整机卡死不再输出 | 检查 Ecode 判断分支有没有把某个 `if` 写成死循环，或者忘了在 `exception_handler` 末尾 `return era + 4;` |
| `Ecode` 数值和别人不一样 | 检查 `(estat >> 16) & 0x3f` 有没有抄错位移/掩码；`ESTAT` 全值应保持稳定，抄错的通常是移位数或掩码位数 |
| 退不出 QEMU | Ctrl+a 然后 x |

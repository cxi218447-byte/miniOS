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
  - `include/exception.h`（**本课要改**：新增 `ecode_from_estat` 声明）
  - `Makefile`（**本课要改**：把新文件加进 `SRCS_S`）
- 本次课要新建的文件：
  - `lib/ecode.S`（纯汇编实现 Ecode 提取，见 Task1 步骤 1）

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

**⚠️ `09-trap-irq` 这个 tag 本次课曾经被老师改过一次内容（修正了重编号前残
留的旧周次标签）**：如果你之前已经 `fetch` 过一次 `09-trap-irq`，这次重新
`git fetch --tags` **很可能不会自动更新它**——Git 默认不会覆盖本地已存在、
但指向了不同 commit 的同名 tag，只会打印一行容易被忽略的提示（`[rejected]
09-trap-irq -> 09-trap-irq  (would clobber existing tag)`），然后悄悄跳过，
不报错。表现为：`kernel/main.c` 里第 8 次课那段看着还是"memset/memcpy 边
界测试"而不是"UART 验收"，或者结尾打印字符串还是 `week10-trap-irq`——说明
你本地这个 tag 还停在重编号之前的旧版本。

确认 + 修复（任选一种）：

```bash
git log -1 09-trap-irq    # 看提交信息里有没有 "fix(09)" 字样，没有就是旧版本
git fetch --tags --force
```

```bash
git tag -d 09-trap-irq
git fetch --tags
```

跑完后重新执行上面的 `git switch -c my-09-lab 09-trap-irq`（如果 `my-09-lab`
已经从旧 tag 建过，先按下面"常见问题"或 `docs/student_git_basics.md` §2 处
理重名分支）。更完整的原理说明见 `docs/student_git_basics.md` §6「老师说某
个 tag 更新了，但你 `git fetch --tags` 之后内容还是旧的」。

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `09-trap-irq`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-09-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. Task1 操作步骤（默认均在已进入的 Ubuntu、仓库根目录；跟着抄代码即可，不需要单独提交任何东西）

**背景知识（两个任务都要用到）**：

**1. Ecode 字段怎么取。** `exception_handler(estat, era)` 的第一个参数
`ESTAT` 里有一个 **Ecode 字段**（第 21–16 位，共 6 位），标识"这次异常具体是哪一种"——
教材 §2.2 已经提过一次（`break` 触发的异常 `Ecode=0xC`），本次课要求你实际把这个字段
从 `estat` 里"抠"出来判断，而不是只在打印时肉眼看十六进制猜。按 LoongArch 调用
约定，第一个参数 `estat` 在 `$a0` 里，取法的纯汇编写法：

```asm
srli.d  $t0, $a0, 16     # 逻辑右移 16 位，把 Ecode 这 6 位移到最低位
andi    $t0, $t0, 0x3f   # 只保留低 6 位（6 个 1），盖掉其余无关位
                         # 此刻 $t0 就是 ecode
```

Task1 步骤 1 会让你把这段汇编原样存成新文件 `lib/ecode.S`，编译成一个真正的函数
`ecode_from_estat`，`kernel/exception.c` 里直接调用它，不再在 C 里写位运算：

```c
unsigned long ecode = ecode_from_estat(estat);
```

`srli.d`（逻辑右移）对应 `>> 16`，`andi`（按位与）对应 `& 0x3f`——和第 8 次课 Task1
进阶部分 `uart_putc_robust` 里"读 → 只留需要的那几位"是同一套思路，只是这次不是
从内存读寄存器，而是从已经读进来的 `estat` 参数（也就是 `$a0`）里挑位；区别在于这次
直接用汇编写成一个独立函数，而不是嵌在 C 表达式里。

**2. `__asm__ volatile("...")` 是什么。** 下面 Task1 步骤 4 的给定代码、以及 Task2 要你
自己新增的 `syscall` 触发，都是这种写法——这是 GCC 的内联汇编扩展语法，把一条机器指令
原样塞进 C 代码里：

- `__asm__`：告诉编译器"接下来这段是汇编指令，不是 C 语句"。
- `volatile`：禁止编译器因为"看不出这条指令产生了什么结果"就把它优化掉或挪动执行
  顺序——对 `break 0`/`.word 0`/`syscall 0` 这种"故意制造异常、没有返回值"的指令
  至关重要，不加 `volatile`，编译器可能认为这条指令"没用"而直接删掉它。
- 双引号里就是一条真实的 LoongArch 汇编指令，跟 `boot/start.S` 里写的是同一套指令
  集，会被原样编译进去。
- 本课 Task1/Task2 要你自己写的触发指令都只用这种最简单的"无操作数"形式。但
  `exception_init`（`kernel/exception.c` 里已经写好，本课不用改）内部用的是
  "带冒号"的完整形式，值得展开认识一下——以后要写"指令需要读写某个 C 变量"的内联
  汇编时会用到，本课不要求你自己动手写，但要能看懂。

**带冒号的完整语法**：

```c
__asm__ volatile("指令模板" : 输出操作数 : 输入操作数 : 被影响的寄存器/内存);
```

用三个冒号隔开四段，哪段没有就留空，但冒号本身不能省（只有从某段往后都不需要时，
才能把那些冒号整体省掉——前面点 1 的"无操作数"形式就是把四段全省了）。以
`exception_init` 这一行为例：

```c
unsigned long entry = (unsigned long)exception_entry;
__asm__ volatile("csrwr %0, 0xc" : : "r"(entry) : "memory");
```

- **指令模板** `"csrwr %0, 0xc"`：`%0` 是占位符，代表"操作数列表里第 0 个"，编译
  器最终会把它替换成实际分配到的寄存器名。
- **输出操作数**（第一个冒号后面）：这里是空的——这条指令不往任何 C 变量里写结果。
- **输入操作数**（第二个冒号后面）：`"r"(entry)`——`"r"` 是约束，告诉编译器"把
  `entry` 的值放进任意一个通用寄存器"，具体用哪个寄存器由编译器挑（可能是 `$t0`，
  也可能是别的），再拿这个寄存器名替换模板里的 `%0`。生成的汇编大致形如
  `csrwr $t0, 0xc`，具体用哪个寄存器你写代码时不用关心。
- **clobber 列表**（第三个冒号后面）：`"memory"`——告诉编译器"这条指令可能影响
  内存"，编译器不能假设指令前后内存内容没变，不会为了优化把内存读写重排到这条指
  令前后。`csrwr` 本身不直接碰内存，但写 EENTRY 这件事关系到"后续代码能不能被异
  常安全打断"，属于编译器看不出来的隐藏副作用，所以保险起见加上 `"memory"`。

**如果还要把执行结果写回 C 变量**（带输出操作数的例子，帮助对比记忆，本课不要求
自己写）：

```c
unsigned long estat;
__asm__ volatile("csrrd %0, 0x5" : "=r"(estat));
```

- `%0` 这次对应的是**输出**操作数 `"=r"(estat)`：前面的 `=` 表示"这是一个输出，
  指令执行完要把结果写回这里"，`r` 仍表示"用任意通用寄存器"。编译器会生成类似
  `csrrd $t0, 0x5`，再把 `$t0` 的值赋给 `estat`。
- 输入、clobber 两段都是空的，直接收尾，不用再写多余的冒号。

记口诀：**模板里的 `%0 %1 ...` 按"输出在前、输入在后"的顺序对应操作数列表；括号
里的 C 变量名告诉编译器要读写哪个变量；约束字符串（`r`/`=r` 等）告诉编译器用什么
方式（通常是某个寄存器）跟这个变量打交道。**

### Task1（跟着做）：区分 BRK 与"未识别"异常 + 亲手踩一次 `era + 4` 的坑

#### 步骤 1：新建 `lib/ecode.S`，用纯汇编实现 Ecode 提取

在仓库根目录新建文件 `lib/ecode.S`，内容如下（对应前面背景知识点 1 的汇编写法）：

```asm
/*
 * 第 9 次课：从 ESTAT 里取出 Ecode 字段（bit[21:16]，共 6 位）。
 * 对应 C 写法：(estat >> 16) & 0x3f —— 这里用纯汇编实现同一件事，
 * 调用方式和普通 C 函数一样：ecode_from_estat(estat)。
 */

    .section .text

    .globl ecode_from_estat
ecode_from_estat:
    srli.d      $a0, $a0, 16      /* 逻辑右移 16 位，Ecode 落到最低 6 位 */
    andi        $a0, $a0, 0x3f    /* 只保留低 6 位，盖掉其余无关位 */
    jr          $ra               /* 返回值仍在 $a0，LoongArch 调用约定 */
```

#### 步骤 2：把新文件接入构建

1. 打开 `include/exception.h`，在 `void exception_init(void);` 下面加一行声明：

   ```c
   /* 从 ESTAT 里取出 Ecode 字段（bit[21:16]），纯汇编实现见 lib/ecode.S */
   unsigned long ecode_from_estat(unsigned long estat);
   ```

2. 打开 `Makefile`，在 `SRCS_S :=` 列表末尾加上新文件（跟现有几行对齐）：

   ```makefile
   SRCS_S := \
   	boot/start.S \
   	lib/string.S \
   	lib/regs_alu.S \
   	lib/mem_fp.S \
   	lib/branch_loop.S \
   	lib/stack_abi.S \
   	lib/ecode.S
   ```

   不加这一行，`lib/ecode.S` 不会被编译，链接时会报 `ecode_from_estat` 未定义。

#### 步骤 3：改 `kernel/exception.c`，让 `exception_handler` 能报出 Ecode

把 `exception_handler` 替换成下面这段完整代码（`exception_init` 不用改，保留原样）：

```c
unsigned long exception_handler(unsigned long estat, unsigned long era)
{
    /* Ecode：ESTAT 的 bit[21:16]，标识"这次异常具体是哪一种"。
     * 编号以实测/讲义为准：0xC 是 break 触发的 BRK。
     * 提取逻辑在 lib/ecode.S 里用纯汇编实现，这里只是调用。 */
    unsigned long ecode = ecode_from_estat(estat);

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

#### 步骤 4：改 `kernel/main.c`，新增第二种异常触发

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

#### 步骤 5：编译运行，确认两条诊断都出现

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

#### 步骤 6：亲手踩一次 `era + 4` 的坑（教材 §3.3）

1. 把 `return era + 4;` 临时改成 `return era;`，重新 `make run`。
2. **只需看第一条 `break` 诊断反复刷屏就够了**——串口会陷入
   "触发异常 → 打印 → ertn 回到 break 指令本身 → 再次触发"的死循环，
   永远走不到后面非法指令那一步。Ctrl+a 再 x 强制退出 QEMU。
3. 改回 `return era + 4;`，重新 `make run`，确认恢复正常（两条诊断都出现，
   打印到 `week09-trap-irq check done` 后停住）。

## 4. 实验任务（只有 Task2 需要提交）

### Task2（进阶，当堂调试 + 截图）：识别 INE，并新增第三种异常来源

**要求**：在 Task1 的基础上（不给代码，只给规格）：

1. **认出非法指令异常**：把 Task1 步骤 5 里观察到的 `Ecode=0xd` 也加进判断分支，
   打印一个你自己起的名字（比如 `"INE"`），不能再停留在 `(unrecognized)`。
2. **新增第三种触发**：在 `kernel_main` 里、非法指令 demo **之后**，用内联汇编执行一条
   `syscall 0` 指令（写法参考步骤 4 里 `.word 0` 的接线方式，指令换成
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

## 5. 验收标准

- `exception_handler` 通过 `lib/ecode.S` 里的 `ecode_from_estat` 正确算出 Ecode
  （`(estat >> 16) & 0x3f`），不是肉眼读十六进制猜出来的。
- 三种异常（`break`/非法指令/`syscall`）各自打印出正确、不同的名字，不允许残留
  `(unrecognized)`。
- 亲手做过 `era + 4` 踩坑实验，能说出去掉 `+ 4` 为什么会死循环。
- 整机不卡死，串口从 `exception_init: ...` 完整打印到 `week09-trap-irq check done`。

## 6. 报告要求

本次实验不要求提交单独的实验报告；学生提交的"报告正文"就是 Task2 里贴的
`exception_handler` 代码文本本身。批改时对照上面的验收标准逐条核对这段代码和
配套截图即可，不需要额外的文字说明。

## 7. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称；确认第 1 周已安装 Ubuntu |
| Ubuntu 里 `command not found: make` | 见 runbook 安装交叉工具链 |
| 找不到 Makefile | 检查是否已在 Ubuntu 中 `cd` 到 miniOS 根目录 |
| 链接报 `undefined reference to 'ecode_from_estat'` | `lib/ecode.S` 没有被编译：检查 `Makefile` 的 `SRCS_S` 列表末尾有没有加上 `lib/ecode.S` 这一行 |
| 加了非法指令/`syscall` 后整机卡死不再输出 | 检查 Ecode 判断分支有没有把某个 `if` 写成死循环，或者忘了在 `exception_handler` 末尾 `return era + 4;` |
| `Ecode` 数值和别人不一样 | 检查 `lib/ecode.S` 里 `srli.d`/`andi` 的位移数、掩码有没有抄错；`ESTAT` 全值应保持稳定，抄错的通常是移位数或掩码位数 |
| `exception_init()` 跑完后 `break`/非法指令触发直接卡死不返回，自己加代码回读 `EENTRY` 发现一直是 `0`（`exception_init` 本身没改过） | 不是代码逻辑错，是**交叉编译器默认开了 PIE**：`(unsigned long)exception_entry` 这种"取函数地址当数据用"的写法，PIE 下会编译成走 GOT 表间接取址，而 miniOS 是裸机内核，没有运行时处理 GOT 重定位这一步，读出来就是 0。只会在用 **Ubuntu apt 装的 `gcc-loongarch64-linux-gnu`**（不是 `docs/manual_wsl_ubuntu22_toolchain_build.md` 推荐的龙芯官方预编译工具链）时出现。`Makefile` 的 `CFLAGS` 2026-10-09 起已经加上 `-fno-pic -fno-pie`，重新 `git pull` 到最新 `master`（或自己的 `Makefile` 手动补这两个 flag）即可；改完一定要先 `make clean` 再 `make`，否则旧的 `.o` 还是 PIE 编译出来的，不会自动重编 |
| 退不出 QEMU | Ctrl+a 然后 x |

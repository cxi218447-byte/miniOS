# 第 3 次课实验指导书参考答案：寄存器、数据表示与基础指令

> 配套：`docs/03/lab.md`（学生版任务书）。
> 本文件为**教师/助教参考答案**，包含完整实现代码与真实运行结果，**不建议直接下发给学生**
> （会让 Task2/Task5/Task6 失去练习意义）。
>
> 下面所有输出、反汇编、寄存器表均为**真实构建结果**：在 WSL Ubuntu 里用
> `git worktree` 检出 `03-regs-alu` 标签、`make clean && make && make run` /
> `objdump` 实际跑出来的，不是手推猜测。

## Task1 跑通

`make clean && make && make run` 真实串口输出（与 lab.md §1 完全一致）：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
arith add/sub: (3+5)-2 = 6
arith mul: 6*7 = 42
logic andi: 0x1234 & 0xff = 0x34
shift slli: 5<<1 = 10
cond slt: (3<5) = 1
bit ext.w.b: 0x7f -> 127
arith temp: (7+1)+(7+1) = 16
mem st.b: see clear_bss
branch: see bl/jr/beq in start.S
misc idle: halt loop below
float: textbook ch4, not run here
week03-regs-alu check done
```

## Task2 参数传递 + 跟算一行（`alu_mul`）

### 2.1 参数传递

命令：

```bash
make clean && make
loongarch64-linux-gnu-objdump -d build/minios.elf | grep -B 2 "<alu_mul>$"
```

真实反汇编（已去掉左侧机器码列，保留地址/助记符/操作数）：

```text
9000000000200194:  li.w  $a1, 7        # 第 2 个参数 b=7 → a1
9000000000200198:  li.w  $a0, 6        # 第 1 个参数 a=6 → a0
900000000020019c:  bl    alu_mul       # 调用；返回地址自动存进 $ra
90000000002001a0:  move  $s0, $a0      # 返回值在 a0，先存到 s0 备用
```

**回答：**

- `6` 被装进了 **`$a0`**；`7` 被装进了 **`$a1`**。
- 调用指令是 **`bl alu_mul`**（地址 `0x20019c`）。
- 对应 C 调用 `alu_mul(6, 7)` 里的**第 1 个实参 `6`**（→ `$a0`）和**第 2 个实参 `7`**（→ `$a1`）——
  与 §3.3 的 `alu_expr(3,5,2)` 例子同一套规则：LP64D ABI 前几个整型参数依次进 `$a0/$a1/…`。

### 2.2 跟算一行

`lib/regs_alu.S` 里 `alu_mul` 的真实实现只有 2 条指令：

```asm
alu_mul:
    mul.d   $a0, $a0, $a1      /* a0 = a * b */
    jr      $ra
```

逐指令快照（`alu_mul(6, 7)`）：

| 步 | 指令 | 计算 | $a0 | $a1 |
|---|---|---|---|---|
| 0 | 入口（参数已按 2.1 传入） | — | 6 | 7 |
| 1 | `mul.d $a0, $a0, $a1` | 6×7=42 | **42** | 7 |
| 2 | `jr $ra`（等价 `ret`） | 返回，$a0=42 就是返回值 | 42 | 7 |

## Task3 课堂知识点打勾（十问参考答案）

1. **`imm < 12 bit` 装立即数：** 用 `addi.* rd, r0, imm[11:0]`（本课对应 `addi.d $t0, $zero, imm12`）——
   立即数先做符号扩展（si12），再与 `r0`（恒 0）相加，直接把常数"装"进目的寄存器。
2. **`12 bit < imm < 32 bit`：** `lu12i.w rd, imm[31:12]` 把立即数**高 20 位**装进寄存器的 `[31:12]` 位、低 12 位补 0；
   `ori rd, rd, imm[11:0]` 再把**低 12 位**通过按位或"拼接"进去。两条指令合起来把一个较大立即数分两段装完。
3. `r2=0x7f0` 时 `andi r5, r2, 3` 的结果是 **`r5 = 0`**（`0x7f0` 低 2 位是 `00`，与 `0b11` 相与仍是 `00`）；
   可用来检查该地址/数值是否**按 4 字节对齐**（低 2 位全 0）。
4. `r4=0xFFFA` 时 `ext.w.h r5, r4` 后 **`r5 = 0xFFFFFFFFFFFFFFFA`**（笔记结果）；
   这是**符号扩展**（把 16 位数当有符号数看，符号位 1 一路向高位补满）。
5. `move rd, rj` 通常等价于 **`or rd, rj, r0`**（即 `or rd, rj, $zero`）。
6. **寄存器宽度：** LA32 上每个整数通用寄存器（GR）是 **32 位**；LA64 上是 **64 位**。
   本课 miniOS（`loongarch64` 交叉工具链、`-mabi=lp64d`）按 **LA64** 理解——每个 `$t0`/`$a0`/… 都是 64 位格。
7. 笔记中 LA64 的 `add.w r5,r2,r1`：**源只取 `r2`/`r1` 的低 32 位**参与运算；
   **写回前**要把 32 位结果做**符号扩展**到 64 位，再整格写入 `r5`。
8. `r1=0x7fffffff; add.w r5,r1,r1`：**LA32** 下 `r5 = 0xfffffffe`；**LA64** 下 `r5 = 0xfffffffffffffffe`；
   两者**有符号读都是 `-2`**（LA64 只是把 LA32 那次 32 位溢出结果再符号扩展了一遍，不是重新溢出）。
9. **`slt` 与 `sltu` 的差别：** `slt` 把两个操作数当**有符号**数（补码）比大小，`sltu` 当**无符号**数比大小——
   同一对比特串，最高位为 1 时两者的大小判断可能完全相反。
10. **`maskeqz rd, rj, rk`：** `rd = (rk == 0) ? 0 : rj`——**条件寄存器 `rk` 等于 0 时把 `rd` 清零**，否则 `rd` 原样取 `rj`。

## Task4（选做）参考示例

把 `alu_expr` 测试从 `(3,5,2)` 改成 `(10,4,3)`：`(10+4)-3 = 11`。

```c
r = alu_expr(10, 4, 3);
printk("arith add/sub: (10+4)-3 = ");
print_i64_dec(r);
printk("\n");
```

`make run` 对应行变为：

```text
arith add/sub: (10+4)-3 = 11
```

## Task5 实现 `alu_min`（参考实现，已在 WSL 真实编译运行验证）

### 5.1 声明 + 实现

`include/regs_alu.h` 新增：

```c
/* 条件选择 min：r = (b<c) ? b : c，仅用 slt/maskeqz/masknez/or */
long alu_min(long b, long c);
```

`lib/regs_alu.S` 新增（只用 `slt`/`maskeqz`/`masknez`/`or`，无分支跳转，与课件例 3.8 完全对应）：

```asm
/* ---- 条件选择：min = (b<c)?b:c，仅 slt/maskeqz/masknez/or，无分支 ---- */
    .globl alu_min
alu_min:
    slt      $t0, $a0, $a1     /* t0 = (b < c) ? 1 : 0 */
    maskeqz  $a0, $a0, $t0     /* a0 = (t0==0) ? 0 : b */
    masknez  $t0, $a1, $t0     /* t0 = (t0!=0) ? 0 : c */
    or       $a0, $a0, $t0     /* a0 = a0 | t0 = min(b,c) */
    jr       $ra
```

`$a0` 全程是同一物理寄存器：入口时装的是参数 `b`，`or` 写回后就是返回值——这正是
`alu_expr` 里 `$a0` 从入口到返回值一路复用的同一套规则。

### 5.2 接入验收串

```c
r = alu_min(3, 5);
printk("logic min: min(3,5) = ");
print_i64_dec(r);
printk("\n");
```

真实 `make clean && make && make run` 新增输出：

```text
arith temp: (7+1)+(7+1) = 16
logic min: min(3,5) = 3
mem st.b: see clear_bss
```

### 5.3 手推快照表（`alu_min(3, 5)`）

| 步 | 指令 | 计算/含义 | b 寄存器 `$a0` | c 寄存器 `$a1` | 条件位寄存器 `$t0` | 返回值寄存器 `$a0` |
|---|---|---|---|---|---|---|
| 0 | 入口 | b=3,c=5 | 3 | 5 | ? | — |
| 1 | `slt $t0,$a0,$a1` | 3<5→1 | 3 | 5 | **1** | — |
| 2 | `maskeqz $a0,$a0,$t0` | t0≠0→a0 保持 b=3 | 3 | 5 | 1 | — |
| 3 | `masknez $t0,$a1,$t0` | t0≠0→t0 清 0 | 3 | 5 | **0** | — |
| 4 | `or $a0,$a0,$t0` | 3\|0=3，返回 | — | 5 | 0 | **3** |

### 5.4 换一组数再推一遍（`alu_min(5, 3)`）

真实重跑输出：

```text
logic min: min(5,3) = 3
```

**哪一步、哪个寄存器被清成了 0？**

这一次 `slt $t0,$a0,$a1` 算的是 `5<3`，结果为**假**，`$t0 = 0`。
接下来 **第 2 步 `maskeqz`** 就把 `$a0`（本来装的是 `b=5`）**清成了 0**
（`maskeqz` 语义：`rk==0` 时 `rd` 清零，这次 `rk=$t0=0` 恰好触发）。
第 3 步 `masknez $t0,$a1,$t0`：因为 `rk=$t0=0`，条件"非零"不成立，`masknez` 把 `$t0` 置为 `$a1=c=3`（保留 c）。
第 4 步 `or`：`0 | 3 = 3`。

**为什么和 `(3,5)` 那次同样正确？**

`maskeqz`/`masknez` 是一对**互补**的清零：同一个条件位 `$t0`，`maskeqz` 在条件为 0 时清 `$a0`（清 b），
`masknez` 在条件非 0 时清 `$t0`（清 c）——**两者永远只会清掉其中一个，保留另一个**，与 `b<c`
判断真假无关，最后 `or` 把"保留下来的那一个"合并出来，正好就是 `min(b,c)`。所以不管走哪条数据路径
（谁被清零），`or` 出来的结果都恒等于两者中较小的那个——这就是"分支消除"能保证结果一致的原因。

## Task6（选做）参考示例：`alu_sltu`（无符号比较，对照 `slt`）

**为什么选这条指令：** 课堂/§3.1.2 讲过 `slt`（有符号）与 `sltu`（无符号）的差别，`regs_alu.S` 里目前
只有 `alu_slt`（有符号），补一个 `alu_sltu` 正好能用同一组输入直接对比出"读法不同、结果可能相反"。

**声明** (`include/regs_alu.h`)：

```c
/* 无符号比较 sltu：r = (a <u b) ? 1 : 0 */
long alu_sltu(long a, long b);
```

**实现** (`lib/regs_alu.S`)：

```asm
/* ---- 无符号比较：sltu ---- */
    .globl alu_sltu
alu_sltu:
    sltu    $a0, $a0, $a1      /* a0 = (a <u b) ? 1 : 0 */
    jr      $ra
```

**接入验收串**：

```c
r = alu_sltu(-1, 1);
printk("logic sltu: (-1 <u 1) = ");
print_i64_dec(r);
printk("\n");
```

真实运行输出：

```text
logic sltu: (-1 <u 1) = 0
```

**说明：** `-1` 的补码比特串是全 1（`0xFFFFFFFFFFFFFFFF`）。`alu_slt(-1, 1)`（有符号）会认为 `-1 < 1`
成立，返回 `1`；而 `alu_sltu(-1, 1)`（无符号）把同一串比特读成一个巨大的正数
（`18446744073709551615`），显然不小于 `1`，所以返回 `0`——**同一个输入、同一个操作数比特，
`slt`/`sltu` 给出相反答案**，正是它俩最容易混淆、也最该讲清楚的地方。

**和已有代码最容易混淆的指令：** `alu_slt` 里的 `slt`——两条指令操作数格式完全一样，
唯一区别就是"有符号 vs 无符号"这一个字母 `u`，但对负数输入的结果可能完全相反。

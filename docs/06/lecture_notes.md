# 第 6 次课教师讲义：函数调用约定与栈帧

> 技术编号：`06`　|　建议检查点：`06-stack-abi`  
> 系统化过程调用，彻底读懂第 1–2 次课的 `bl` / `jr $ra`。

## 0. 一句话目标

掌握 LoongArch 教学用调用约定与最小栈帧，能解释叶子/非叶子函数，并能对照 `clear_bss`、`kernel_main` 与 `exception_entry`。

## 1. 课程定位（Why）

第 1–2 次课反复出现：

```asm
bl   clear_bss
bl   kernel_main
jr   $ra
```

第 5 次课解决了函数**内部**的循环结构；本次课解决函数**之间**如何交接：

> 参数在哪？返回值在哪？谁保存 `$ra`？栈帧长什么样？

## 2. 教学目标

1. 记住：整型/指针参数优先走 `$a0`–`$a7`，返回值主要在 `$a0`。  
2. 理解 `bl` 写入 `$ra`，`jr $ra` 返回。  
3. 区分叶子函数与非叶子函数；非叶子必须保存 `$ra`。  
4. 会画最小栈帧：伸栈 → 存 `$ra` → 体 → 取 `$ra` → 折栈 → 返回；知道栈帧大小为何必须是 16 的倍数。  
5. **说清 caller-saved（`$t*`/`$a*`/`$ra`）与 callee-saved（`$s0`–`$s8`/`$fp`）的区别**——这是第 3 次课点名留到本课的内容。  
6. 能用 `strlen`（单参数、叶子）和 `uart_puts`（C 写的非叶子）两个已认识的函数复述上述约定。  
7. 能解释 `exception_entry` 中保存 `$ra` 的原因（为第 12 次课铺垫）。

## 3. 课前准备

- 复习第 3 次课寄存器角色（尤其是它点名留到本课的 `$s*`/`$fp`/`$tp`）、第 4 次课 `$sp+offset` 访存。  
- 打开 `lib/string.S` 的 `memset`/`strlen` 入口、`kernel/printk.c` 的 `uart_puts`，与 `boot/start.S` 的 `exception_entry`。

## 4. 课程知识

### 4.1 调用约定（LP64D，第 3 次课的欠账在此结清）

第 3 次课讲过 `$ra/$a*/$t*`，并两次点名："`$s*`/`$fp`/`$tp` 等在第 6 次课展开"、"第 6 次课再管保存规则"。这里给出完整寄存器角色表，把账结清（浮点分支 `$fa0`–`$fa7`/`$fs*`/`$ft*` 已在第 4 次课讲过，规则与此处整数分支一致，不重复）：

| 寄存器 | 编号 | 角色 | 谁负责保存 |
|---|---|---|---|
| `$zero` | r0 | 恒为 0 | — |
| `$ra` | r1 | 返回地址（`bl` 写入） | **caller-saved**：调用前还要用就自己先存 |
| `$tp` | r2 | 线程指针 | 保留寄存器；裸机单线程阶段不使用，不要挪作他用 |
| `$sp` | r3 | 栈指针，向低地址增长 | 函数退出前必须恢复为进入时的值 |
| `$a0`–`$a7` | r4–r11 | 前 8 个整数/指针参数；返回值主要在 `$a0`（必要时 `$a0`+`$a1` 兼两个返回值） | **caller-saved** |
| `$t0`–`$t8` | r12–r20 | 临时寄存器 | **caller-saved**：`bl` 之后不能假设还是原值 |
| `$fp`（即 `$s9`） | r22 | 帧指针，可选 | **callee-saved** |
| `$s0`–`$s8` | r23–r31 | 通用"跨调用"暂存寄存器 | **callee-saved** |

**caller-saved / callee-saved 到底在约束谁：**

- **caller-saved**（`$t*`/`$a*`/`$ra`）：调用者如果指望某个值在 `bl` 之后还在，必须自己先存到栈上；被调用者可以随便覆写，不用负责恢复。`sa_add3` 目前用栈上局部变量（`st.d $a2, $sp, 16`）保存 `c`，本质也是"调用者自己存"，只是存的地方从寄存器换成了内存。
- **callee-saved**（`$s0`–`$s8`/`$fp`）：被调用者如果借用这些寄存器（比如想跨越两次 `bl` 暂存一个值，而不占内存），必须在函数入口把原值存下、出口恢复成调用前的样子——不管调用者用不用它，"借了就要原样归还"。这是第 3 次课点名要在本课交代的规则，也是它和 `$t*` 的本质区别：`$t*` 是"用完即弃"，`$s*` 是"用了要还"。

**栈 16 字节对齐（是 ABI 硬性要求，不是代码风格）：**

- LP64D 规定函数入口处 `$sp` 必须是 16 字节对齐。`sa_add3` 开 32 字节栈帧（`addi.d $sp, $sp, -32`）满足这条；即使只需要保存 8 字节的 `$ra`，也要凑够 16 的倍数，不能开 8 字节栈帧。
- 这条约束贯穿全程：第 9 次课 `exception_entry` 的栈帧更大，同样要满足 16 字节对齐，不是本课的特例。

**命名说明：** 本课程用的具体 ABI 是 **LP64D**（64 位整数 + 硬件浮点）。"调用约定"不是放之四海皆准的规则，而是这一 ABI 的选择——参数寄存器怎么分工、栈怎么对齐，都是 LP64D 定的。

### 4.2 叶子函数

#### 汇编精讲

```asm
# int add_one(int x)  →  $a0 = x, 返回值 $a0
add_one:
    addi.d  $a0, $a0, 1
    jr      $ra
```

1. 不调用其他函数，`$ra` 不会被覆盖。  
2. 参数已在 `$a0`，结果写回 `$a0`。  
3. `jr $ra`：跳到返回地址。

### 4.3 非叶子函数

#### 汇编精讲

```asm
foo:
    addi.d  $sp, $sp, -16
    st.d    $ra, $sp, 8
    bl      bar              # 这里会改写 $ra
    ld.d    $ra, $sp, 8
    addi.d  $sp, $sp, 16
    jr      $ra
```

1. **`addi.d $sp, $sp, -16`**：向低地址分配栈帧。  
2. **`st.d $ra, $sp, 8`**：保存返回地址。  
3. **`bl bar`**：进入子函数；返回后应回到 `ld.d` 处。  
4. **对称恢复** `$ra` 与 `$sp`，再 `jr $ra`。  

**关键结论**：若漏存 `$ra`，嵌套调用后无法返回正确位置。

### 4.4 对照工程代码

#### `_start` 中的两次调用

```asm
    bl   clear_bss
    bl   kernel_main
```

- `clear_bss` 必须以 `jr $ra` 正确返回，第二次 `bl` 才有意义。  
- `_start` 本身在 `kernel_main` 返回后进入 halt，不依赖再返回“更上层”。

#### `memset` 的参数槽

```asm
memset:                 # void *memset(void *s, int c, size_t n)
    move    $t0, $a0    # 保存 dst 以便返回
    ...
    move    $a0, $t0
    jr      $ra
```

| C 参数 | 寄存器 |
|---|---|
| `s` | `$a0` |
| `c` | `$a1` |
| `n` | `$a2` |
| 返回 `s` | `$a0` |

#### `strlen` 只用一个参数

```asm
strlen:
    move        $t0, $a0    /* 记录起始地址 */
1:
    ld.bu       $t1, $a0, 0
    beqz        $t1, 2f
    addi.d      $a0, $a0, 1
    b           1b
2:
    sub.d       $a0, $a0, $t0
    jr          $ra
```

对照 `memset` 的三个参数（`$a0/$a1/$a2`），`strlen`（第 2 次课已实现，见 `lib/string.S`）只用 `$a0`——参数少不代表约定变简单，返回值一样要落回 `$a0`。它是叶子函数（不调用别的函数），不用碰 `$ra`。第 7 次课会在这个约定基础上补齐边界测试（空串、单字符等），把它从"能跑"验证到"边界正确"。

#### `uart_puts`：C 函数之间也遵守同一套约定

```c
void uart_puts(const char *s)   /* s 在 $a0，与汇编函数走的是同一个寄存器 */
{
    while (*s) {
        if (*s == '\n') uart_putc('\r');   /* uart_puts 调 uart_putc，$a0 重新装载 */
        uart_putc(*s++);
    }
}
```

`uart_puts`（第 1 次课已用上，见 `kernel/printk.c`）是一个纯 C 写的非叶子函数：编译器同样把参数 `s` 放进 `$a0`，内部调用 `uart_putc` 前后也要遵守 caller-saved/callee-saved 规则——只是这些细节被编译器自动生成，不用手写。**调用约定不是"手写汇编才要守的规矩"，是 GCC 编译出的代码也必须遵守的接口契约。** 第 8 次课会把 `printk → uart_puts → uart_putc → MMIO` 整条链路讲透。

#### `sa_strlen_and_puts`：把 `strlen`/`uart_puts` 和 `$s0`/`$s1` 接在一起（可运行）

```asm
sa_strlen_and_puts:
    addi.d  $sp, $sp, -32
    st.d    $ra, $sp, 24
    st.d    $s0, $sp, 16       /* 借用前先存调用者的 $s0 */
    st.d    $s1, $sp, 8        /* 借用前先存调用者的 $s1 */

    move    $s0, $a0           /* s0 = s，跨越下面两次 bl 保存 */
    bl      strlen
    move    $s1, $a0           /* s1 = len，跨越下面这次 bl 保存 */

    move    $a0, $s0           /* 取回 s（未被 strlen 改写） */
    bl      uart_puts

    move    $a0, $s1           /* 返回值 = len */

    ld.d    $s1, $sp, 8
    ld.d    $s0, $sp, 16
    ld.d    $ra, $sp, 24
    addi.d  $sp, $sp, 32
    jr      $ra
```

这是本课**唯一同时用到 `$ra` 和 `$s*` 两种保存规则的函数**（`lib/stack_abi.S`，`make run` 可见输出）：

1. 两次 `bl`（`strlen`、`uart_puts`）都会改写 `$ra`，所以入口必须先存 `$ra`——和 `sa_add3` 一样。
2. `$a0` 在第一次 `bl` 之后就变成了 `strlen` 的返回值（长度），原来的字符串指针 `s` 已经找不回来了；`$t0`/`$t1` 也可能被 `strlen`/`uart_puts` 内部随意改写——这些都是 caller-saved，用坏了不奇怪。
3. 所以 `s` 必须存进 **callee-saved** 的 `$s0`：`strlen`/`uart_puts` 无论内部怎么写，都不允许改写 `$s0`，这是它们作为被调用者的义务，不是本函数自己小心维护的结果。同理，`len` 存进 `$s1` 才能扛过第二次 `bl`。
4. `$s0`/`$s1` 是**借来的**（属于本函数的调用者），所以入口存、出口取，缺一步都会破坏调用者原来的值——这一步不是为了保护自己，是为了不祸害上层。

#### `exception_entry` 预告

```asm
    addi.d  $sp, $sp, -32
    st.d    $ra, $sp, 24
    ...
    bl      exception_handler
    ld.d    $ra, $sp, 24
    ...
    ertn                 # 注意：异常返回不是 jr $ra
```

模式相同：为调用 C 保存 `$ra`；最终返回路径不同（`ertn`）。

## 5. 课堂 Demo

1. 叶子 vs 非叶子：板书 `$ra` 时间线。  
2. 让学生在 `memset` 上标注三个参数寄存器。  
3. （可选）GDB 在 `bl` 前后打印 `$ra`。
4. 可运行 demo：`lib/stack_abi.S`——`sa_add_one`（叶子）与 `sa_add3`（非叶子，内部两次 `bl sa_add`）。刻意演示：若 `sa_add3` 不在入口先保存自己的 `$ra`，第一次 `bl` 就会把它覆盖，第二次 `bl` 返回后 `jr $ra` 将跳到错误位置——这正是 Task C 的答案。
5. 可运行 demo：`sa_strlen_and_puts`——内部真调第 2 次课的 `strlen`、第 1 次课的 `uart_puts`，用 callee-saved 的 `$s0`/`$s1` 跨两次 `bl` 保存字符串指针与长度。板书对照：`$ra` 存/取是「回家的路」，`$s0`/`$s1` 存/取是「借来的椅子用完要放回原位」——纪律相同，对象不同（对应 Task3b）。
6. `make run` 核对 `week06-stack-abi check done`，串口应能看到 `sa_strlen_and_puts` 打印出的字符串本身（来自内部的 `uart_puts` 调用）。

## 6. 实验实践

**Task A**  
实现 `int add3(int a, int b, int c)` 汇编版，C 中调用并 `printk` 结果（或返回后用已知方式观察）。

**Task B**  
给 `foo→bar` 嵌套画栈帧草图。

**Task C**  
判断：下列函数是否必须保存 `$ra`？  
- 只做 `addi` 后返回  
- 内部 `bl printk`  

**Task D**  
若把 `sa_add3` 里 `st.d $a2, $sp, 16` 暂存 `c` 的写法，改成用 `$s0` 存 `c`（`move $s0, $a2` 代替入栈），还需要多做哪一步才合法？为什么——这一步体现的是 caller-saved 还是 callee-saved 规则？

## 7. AI 共学

允许检查栈帧是否成对；要求学生能讲解“为何非叶子要存 `$ra`”。

## 8. 思考与拓展

1. 栈溢出典型症状有哪些？  
2. 变参函数为何更麻烦（点到为止）？  
3. 内联函数如何减少 `bl/jr`？

## 9. 板书

```text
参数 $a0..$a7  返回 $a0  返回地址 $ra  （LP64D）
t*/a*/ra = caller-saved，用完即弃；s0-s8/fp = callee-saved，借了要还
栈 16 字节对齐：ABI 硬性要求，不是习惯
bl = 调走并记下回家路
非叶子：sp↓  存ra  bl  取ra  sp↑  jr ra
回看：clear_bss / memset / strlen / uart_puts / exception_entry
```

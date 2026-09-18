# 第 10 号课外自学材料：构建、链接与调试

> **2026-09-17 更新：本材料转为课外自学，不再是课堂课次，不占用课堂学时**（详见
> `docs/course_structure.md` §2.7；腾出的 2 学时给了第 5 次课扩容）。第 11、12
> 次课编号、tag、目录均不受影响，正常按原计划上课。学生可在第 9 次课之后自行
> 阅读本材料并用下方检查点验证，但**不作为第 11 次课的前置强制要求**。
>
> 技术编号：`10`　|　**可选自学验收 tag**：`10-build-debug`（与 `09-trap-irq` 同一提交，本课不新增源文件；不再是课堂检查点）  
> 合并原第 7 次课（Makefile/链接脚本/镜像结构）+ 原第 8 次课（GDB 调试与反汇编分析），
> 由 4 学时压缩为 2 学时：本材料只保留“看懂构建链路”与“能用工具验证”两个最小闭环。
>
> **2026-09-07 更新（历史记录）**：本学期曾把本课移到课堂的第 10 次课位置，作为理论部分的收官——
> 讲到这里时，学生已具备 `memset/memcpy/strlen`（第 7 次课）、UART/`sys_write`（第 8 次课）、
> 异常与中断（第 9 次课）的完整代码，`objdump`/GDB 现场验证可覆盖更完整的调用链路；
> 2026-09-17 起改为课外自学，正文内容未变，仅课堂地位变化。

## 0. 一句话目标

看懂源码到镜像的构建/链接链路，并能用 `objdump`/GDB 单步验证 `bl` 前后 `$ra` 的变化。

## 1. 课程定位（Why）

学生已会 `make && make run`，也理解指令、循环与调用约定。本次课把“它是怎么跑起来的”钉死成可验证的事实，分两半：

```text
看懂哪来的（构建/链接）→ 验证怎么跑的（objdump/GDB）
```

两半天然是一体两面：链接脚本决定了符号和地址，GDB/objdump 就是拿这些符号和地址去现场核对。

## 2. 教学目标

1. 解释 `CROSS_COMPILE`/`CFLAGS`/`LDFLAGS`/`SRCS_C`/`SRCS_S`，说明 `-ffreestanding -nostdlib` 的教学含义。
2. 读懂 `ENTRY(_start)`、`KEEP(*(.text.boot))`、`__bss_start/__bss_end`——它们是 `clear_bss` 边界符号的来源，不是 C 数组。
3. 区分 ELF（含符号/调试信息）与 raw binary。
4. 用 `objdump -d`/`readelf -S`/`nm` 定位 `_start`/`clear_bss`/`kernel_main`。
5. 用 `make debug` + GDB 下断点、单步，记录 `bl` 前后 `$ra` 的变化，印证第 6 次课。

## 3. 课前准备

```bash
make clean && make
loongarch64-linux-gnu-readelf -S build/minios.elf
loongarch64-linux-gnu-nm build/minios.elf | head
make debug          # 另开终端：gdb-multiarch build/minios.elf
```

确认工具链带调试信息：`CFLAGS` 含 `-g`。

## 4. 课程知识

### 4.1 构建链路总览

```text
.c / .S  --编译--> .o  --链接 linker.ld--> minios.elf --objcopy--> minios.bin
                                              ↑
                                         ENTRY(_start)
                                         __bss_start/end
```

| 变量/目标 | 作用 |
|---|---|
| `CROSS_COMPILE` | `loongarch64-linux-gnu-` 前缀 |
| `CFLAGS` | `-ffreestanding -nostdlib -mabi=lp64d -g ...` |
| `LDFLAGS` | `-T kernel/linker.ld -static` |
| `SRCS_C` / `SRCS_S` | 参与链接的源文件列表 |
| `run` / `debug` | QEMU `-kernel build/minios.elf`；`debug` 加 `-S -s` 等待 GDB |

**freestanding / nostdlib**：不假设完整托管环境与默认 C 运行时；启动与库函数要自己提供（对应我们的 `start.S`、`string.S`）。

### 4.2 链接脚本精读

```ld
ENTRY(_start)

SECTIONS
{
    . = 0x9000000000200000;

    .text : ALIGN(4K) {
        KEEP(*(.text.boot))
        *(.text .text.*)
    }

    .rodata : ALIGN(4K) { *(.rodata .rodata.*) }
    .data   : ALIGN(4K) { *(.data .data.*) }

    __bss_start = .;
    .bss : ALIGN(4K) {
        *(.bss .bss.*)
        *(COMMON)
    }
    __bss_end = .;
}
```

1. **`ENTRY`**：入口符号必须与启动文件一致。
2. **`.` 位置计数器**：决定 VMA 布局。
3. **`KEEP(.text.boot)`**：避免启动段被优化丢弃。
4. **`__bss_start/__bss_end`**：给 `clear_bss` 用的边界符号，不是 C 数组。
5. **段顺序**：影响地址空间图像，也影响谁紧挨着谁。

对应汇编：`boot/start.S` 里 `.section .text.boot, "ax"` + `.globl _start`——`.text.boot` 必须被链接脚本收集，`.globl` 使符号对外可见，供 `ENTRY` 引用。

### 4.3 ELF vs BIN

| 文件 | 特点 | 用途 |
|---|---|---|
| `minios.elf` | 段、符号、可含调试信息 | QEMU `-kernel`、GDB |
| `minios.bin` | 纯装载内容 | 某些裸加载/烧录场景 |

`objcopy -O binary`：剥掉 ELF 元数据。

### 4.4 用 objdump/GDB 验证

反汇编阅读口诀：

```bash
loongarch64-linux-gnu-objdump -d build/minios.elf | less
```

1. 找符号名 → 2. 看地址是否落在链接脚本窗口附近 → 3. 对 `bl/b/beq` 画箭头 → 4. 对 `ld/st` 标出方向（Mem↔Reg）。

GDB 最小剧本：

```text
target remote :1234
symbol-file build/minios.elf
b _start
b clear_bss
b kernel_main
c
si
info registers
x/16xb $sp
```

| 命令 | 作用 |
|---|---|
| `b` | 断点 |
| `c` | 继续 |
| `si` | 单步指令 |
| `n` | 源码级下一行（依赖调试信息） |
| `p/x $ra` | 打印寄存器 |
| `x` | 检查内存 |

### 4.5 关键观察点：`bl` 前后 `$ra`（对照第 6 次课）

```asm
    bl   clear_bss
    # 返回后应回到这里
```

1. 步入前记下 `$pc`、`$ra`。
2. 进入后 `$pc` 在 `clear_bss`，`$ra` 指向返回点。
3. 在 `jr $ra` 处再观察是否回到返回点——这是第 6 次课“非叶子函数必须存 `$ra`”的现场证据。

### 4.6 常见故障（课堂要会判）

| 现象 | 可能原因 |
|---|---|
| 链接缺符号 | `SRCS_*` 漏文件 |
| 能链接无启动 | `ENTRY`/段错误 |
| `clear_bss` 异常 | 边界符号或 `.bss` 布局错 |
| GDB 无符号 | 未用带 `-g` 的 ELF |
| `si` 走位怪异 | `-O2` 优化后源码行与指令不再一一对应，改用 `si` 而非 `n` |

## 5. 课堂 Demo（合并流程，建议 40–45 分钟）

1. `make -n` 看真实命令；`readelf -S`/`nm` 找 `.text/.data/.bss` 与 `_start`/`__bss_*`。
2. 临时（演示后恢复）去掉 `lib/string.S`，看缺符号错误。
3. `make debug` + GDB：在 `_start`、`clear_bss`、`kernel_main` 下断点，`c`/`si` 走一遍。
4. 步入 `bl clear_bss` 前后，打印 `$pc`/`$ra`，对照 §4.5。
5. 对比：只看 C 行 vs 看真实指令。

## 6. 实验实践

**Task A**　画出本仓库构建依赖图（源文件→.o→elf→bin→qemu）。

**Task B**　书面解释：`KEEP(*(.text.boot))` 与 `__bss_start/__bss_end` 为什么重要。

**Task C**　`make debug` + GDB：在 `_start`/`clear_bss`/`kernel_main` 下断点，记录至少两处 `$pc/$sp/$ra`，重点记录 `bl clear_bss` 前后 `$ra` 的变化。

**Task D（选做）**　`readelf`/`nm`/`objdump -d` 摘录 `_start` 与 `__bss_*` 相关行。

## 7. AI 共学

允许解释参数含义、GDB 命令；链接报错与寄存器数值必须以真实日志/真实调试会话为准，不得编造。

## 8. 思考与拓展

1. 只保留 `.bin` 会失去哪些调试能力？
2. `si` 与 `n` 在有无调试信息时体验有何不同？
3. 起始地址改错时，如何用 `objdump` 发现？
4. 板级没有 GDB 时，如何用 `printk` 做穷人调试？

## 9. 板书

```text
.c/.S → .o → (linker.ld) elf → bin
ENTRY(_start)  KEEP(.text.boot)
__bss_start ... __bss_end  → clear_bss
objdump 找路 → GDB 走路：bl 前后看 $ra
```

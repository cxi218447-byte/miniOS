# 第 7 次课实验指导书：独立实现 strncmp

> 技术编号：`07`　|　检查点：`07-libc-asm`
> 配合讲义：`docs/07/lecture_notes.md`、PPT：`docs/07/07.pptx`
> **环境总手册：** `docs/student_env_runbook.md`

## 1. 实验目标

今天学了 `memset`/`memcpy`/`strlen`/`memmove`/`strcmp`/`zero_and_copy` 六个函数。
本次实验只有**一个编程任务**：独立实现第七个——`strncmp`，`strcmp` 的"最多比较
n 个字符"版本。不给任何汇编代码，自己写。

**提交要求同样只有一个：** 跑通后截图，上传截图即可，不用交报告。

## 2. 准备（已做过第 1–6 次课的同学可跳过）

进入 WSL Ubuntu 后，在仓库里切出本次课分支：

```bash
git fetch --tags
git switch -c my-07-lab 07-libc-asm
```

克隆仓库、装工具链等首次准备步骤见 `docs/student_env_runbook.md`；必须在
**WSL Ubuntu** 终端（不是 PowerShell）里 `make`。

## 3. 任务：实现 `strncmp`

**函数原型**：`int strncmp(const char *a, const char *b, size_t n)`

| 寄存器 | 含义 |
|---|---|
| `$a0` | 字符串 `a` 的地址 |
| `$a1` | 字符串 `b` 的地址 |
| `$a2` | `n`：最多比较的字节数 |
| 返回（`$a0`） | 0：前 n 个字节相等（或双方在 n 个字节内已同时遇到 `'\0'`）；非 0：第一个不同字节的差值 |

**行为约定**（对照今天学的 `strcmp`，只是多了一个"最多比几个"的限制）：

- `n == 0`：不读取 `a`/`b` 的任何字节，直接返回 0。
- 比较到第 n 个字节为止：如果前 n 个字节全部相同，即使后面还有不同字符，也
  返回 0（不能比过 n）。
- 如果在第 n 个字节以内遇到不同字节，返回那一对字节的差值（同 `strcmp`：
  无符号加载后相减，教学简化，不做饱和处理）。
- 如果在第 n 个字节以内两边同时读到 `'\0'`，直接判定相等，返回 0（不需要凑满 n 次）。

**要求**：

1. 在 `include/string.h` 里加一行声明。
2. 在 `lib/string.S` 里独立实现——自己写循环处理 `n`，不允许直接调用现成的
   `strcmp` 再敷衍了事（那样处理不了 `n` 的截断）。
3. 在 `kernel/main.c` 里用 `printk` 验证，至少覆盖以下三种情况，参考 `strcmp`
   那段 `if (strcmp(...) == 0) { printk(...); }` 的写法自己写三个：
   - 前 n 个字节相同、n 之外不同 → 应判定相等
   - 在 n 个字节以内出现不同字节 → 应判定不等
   - `n == 0` → 应判定相等

## 4. 验收与提交

```bash
make clean
make
make run
```

串口里能看到你自己写的三行验证输出（内容和上面三种情况对应，格式自定）。

**截图这部分串口输出，上传截图。就这一步，不用交代码、不用写报告。**

## 5. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `undefined reference to 'strncmp'` | 只在 `.h` 声明、没在 `lib/string.S` 实现，或忘了 `.globl strncmp` |
| `n=0` 时崩溃/读到垃圾 | 循环入口要先判断 `$a2==0`，不能先读一个字节再判断 |
| 前 n 相同也被判成不等 | 检查计数减到 0 时是否正确返回相等，而不是继续往后读 |

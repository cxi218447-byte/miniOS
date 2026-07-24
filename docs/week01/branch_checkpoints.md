# 第 1 周分支使用说明：课堂进度检查点

## 1. 为什么需要这些分支

第 1 周的目标是让学生看到 miniOS 从"CPU 有入口但什么都不做"，一步步长成"看到 Hello miniOS 输出"。如果只在 `master` 上直接展示最终代码，学生看不到这个过程是怎么一步步搭起来的。

这几个分支就是把这个过程拆成可以直接 `checkout` 的检查点，方便课堂上快速切换到对应进度，不用现场手改代码演示。

`master` 分支不受影响，仍然是仓库的最新开发进度（当前已经包含第 2 周 `.data/.bss` 相关代码）。这些分支是从 `master` 单独分出来、逐级递进的一条线。

## 2. 分支列表

```text
week01-00-skeleton
  ↓
week01-01-stack-setup
  ↓
week01-02-kernel-main-empty
  ↓
week01-03-printk-uart
  ↓
week01-qemu-hello   （与 week01-03-printk-uart 是同一个提交）
```

| 分支 | 改了什么 | CPU 实际在做什么 | QEMU 输出 |
|---|---|---|---|
| `week01-00-skeleton` | `_start` 只有一条跳转 | 进入 `halt` 死循环，原地打转 | 无输出 |
| `week01-01-stack-setup` | `_start` 加上 `la.global $sp, boot_stack_top` | 设置好内核栈，然后还是原地打转 | 无输出 |
| `week01-02-kernel-main-empty` | `_start` 加上 `bl kernel_main` | 跳进 C 代码，但 `kernel_main()` 是空函数 | 无输出 |
| `week01-03-printk-uart` | `kernel_main()` 加上 `printk(...)` | 调用 `printk` 把字符串写到 UART | `Hello miniOS on LoongArch64` |
| `week01-qemu-hello` | 无（同 `week01-03-printk-uart`） | 同上 | 同上，对应 `docs/course_release_index.md` 里已定义的正式 tag 名 |

每个分支只改了 `boot/start.S` 和 `kernel/main.c` 这两个文件，`Makefile`、`kernel/linker.ld`、`kernel/printk.c`、`include/uart.h` 等其余文件在所有分支上都保持不变。

## 3. 课堂上怎么用

依次切换分支、编译、运行，让学生看到输出从"什么都没有"变成"Hello miniOS"：

```bash
git checkout week01-00-skeleton
make clean && make && make run
# 预期：QEMU 里没有任何输出，只能看到它没有崩溃

git checkout week01-01-stack-setup
make clean && make && make run
# 预期：仍然没有输出，但可以配合 GDB 看到 $sp 已经被设置

git checkout week01-02-kernel-main-empty
make clean && make && make run
# 预期：仍然没有输出，但可以在 kernel_main 打断点，证明 CPU 真的进了 C 代码

git checkout week01-03-printk-uart
make clean && make && make run
# 预期：终端出现 Hello miniOS on LoongArch64
```

退出 QEMU：`-nographic` 模式下先按 `Ctrl-a`，松开后再按 `x`。

演示结束后切回日常开发进度：

```bash
git checkout master
```

## 4. 和现有 tag 方案的关系

`docs/course_release_index.md` 里已经规划了按周发布的 tag（如 `week01-qemu-hello`），用于学生获取"本周最终版"代码。这里的 `week01-qemu-hello` 分支内容和那个规划中的 tag 是同一个状态，可以直接把这个分支打成 tag：

```bash
git tag week01-qemu-hello-v1 week01-qemu-hello
```

`week01-00` 到 `week01-03` 这几个更细的检查点分支是新增的，只服务于课堂现场演示"从 0 到 Hello 的过程"，不在 `course_release_index.md` 的每周发布索引范围内，不需要单独打 tag 分发给学生。

## 5. 尚未验证

这几个分支的代码是按照 `boot/start.S` 和 `kernel/main.c` 的现有逻辑推演写出来的，本机没有安装 LoongArch 交叉工具链，**没有实际执行过 `make clean && make && make run` 验证**。

正式在课堂上使用前，必须先在有工具链的机器上把 5 个分支各自跑一遍，确认：

- 每个分支都能 `make` 成功。
- `week01-00` 到 `week01-02` 确实没有终端输出。
- `week01-03` / `week01-qemu-hello` 确实输出 `Hello miniOS on LoongArch64`。

跑完之前，不能把这些分支当作"已验证通过"。

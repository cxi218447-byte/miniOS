# LoongArch 汇编 miniOS 实验（第 1 次课）

请从本 tag 新建实验分支：

```bash
git switch -c my-week01-lab week01-qemu-hello
```

第 1 次课验收输出：

```text
Hello miniOS on LoongArch64
```

本 tag **不包含** 后续课次代码：无 `clear_bss`、无 `lib/string.S`、无异常/系统调用。

编译运行：

```sh
make clean && make && make run
```
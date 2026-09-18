# 第 5 次课前置准备：安装 qemu-user

> 请在**第 5 次课上课前**完成，只需要做一次。配合实验指导书：`docs/05/lab.md`。

## 这是什么、为什么要装

第 5 次课有两个独立于 miniOS 仓库的最小汇编练习（Task1/Task2），跑在
`qemu-loongarch64`（QEMU 的**用户态模拟**）上。之前几次课用的
`qemu-system-loongarch64`（**全系统模拟**，miniOS 实验一直用这个）已经装过了，
但 `qemu-loongarch64` 是新工具，需要额外装一次。

## 安装步骤

**在 WSL Ubuntu 终端里**（不是 Windows PowerShell）执行：

```bash
sudo apt update
sudo apt install -y qemu-user
```

会提示输入密码（就是你登录 Ubuntu 用的密码，输入时屏幕上不会显示字符，属于正常现象），输入后回车。

## 验证是否装好

```bash
which qemu-loongarch64
```

能打印出一行路径（类似 `/usr/bin/qemu-loongarch64`）就说明装好了。

## 常见问题

| 现象 | 处理 |
|---|---|
| `sudo apt install` 报找不到包 | 先执行 `sudo apt update` 再重新执行安装命令 |
| 提示输入密码但一直没反应 | 确认是在 WSL Ubuntu 终端里直接输入，不是通过脚本/远程转发执行；正常终端里输入密码不会有回显（包括光标都不动），输完直接回车即可 |
| `which qemu-loongarch64` 没有任何输出 | 说明还没装好，回到"安装步骤"重新执行一遍 |

装好之后不用做别的，第 5 次课上课时直接按 `docs/05/lab.md` 的 Task1/Task2 操作即可。

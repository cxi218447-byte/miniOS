# miniOS 12 次课教师讲义总索引

> **第 1–2 次课主题固定**（Hello / `.data/.bss`）。  
> **从第 3 次课起**系统回填寄存器、基础指令、访存、程序设计与调用约定，再进入内核服务、构建调试、板级与综合。  
> **第 11–12 次课为纯实验课**（各 4 学时连排），理论部分到第 10 次课结束。  
> 详细规则与 2026-08-29 学时重排说明：[course_structure.md](course_structure.md)

| 课次 | 技术编号 | 主题 | 讲义 |
|---|---|---|---|
| 第 1 次课 | `01` | 从 0 启动 LoongArch miniOS | [01/lecture_notes.md](01/lecture_notes.md) |
| 第 2 次课 | `02` | `.data/.bss` 与 C/汇编混合启动 | [02/lecture_notes.md](02/lecture_notes.md) |
| 第 3 次课 | `03` | 寄存器、数据表示与基础指令 | [03/lecture_notes.md](03/lecture_notes.md) |
| 第 4 次课 | `04` | 访存指令与内存数据组织 | [04/lecture_notes.md](04/lecture_notes.md) |
| 第 5 次课 | `05` | 分支、循环与汇编程序设计基础 | [05/lecture_notes.md](05/lecture_notes.md) |
| 第 6 次课 | `06` | 函数调用约定与栈帧 | [06/lecture_notes.md](06/lecture_notes.md) |
| 第 7 次课 | `07` | `memset/memcpy/strlen` 汇编实现 | [07/lecture_notes.md](07/lecture_notes.md) |
| 第 8 次课 | `08` | UART 驱动、输出子系统与系统调用 `sys_write`（合并原 UART 驱动 + 系统调用 sys_write） | [08/lecture_notes.md](08/lecture_notes.md) |
| 第 9 次课 | `09` | 异常与中断处理（合并原异常入口/异常上下文 + 中断基础与定时器理论） | [09/lecture_notes.md](09/lecture_notes.md) |
| 第 10 次课 | `10` | 构建、链接与调试（合并原 Makefile/链接脚本/镜像结构 + GDB 调试与反汇编分析） | [10/lecture_notes.md](10/lecture_notes.md) |
| 第 11 次课 | `11` | 中断/定时器实验 + miniOS 内核服务整理（纯实验，4 学时连排） | [11/lecture_notes.md](11/lecture_notes.md) |
| 第 12 次课 | `12` | 板级迁移 + 综合实验：从 miniOS 到 Agent OS（纯实验，4 学时连排） | [12/lecture_notes.md](12/lecture_notes.md) |

**2026-09-07 更新**：第 7/8/9/10 次课重排，「构建、链接与调试」从第 7 次课移到第 10 次课（理论收官），原第 8/9/10 次课依次前移为第 7/8/9 次课；`docs/` 目录、代码 tag（`07-libc-asm`/`08-uart-syscall`/`09-trap-irq`/`10-build-debug`）与相关源码注释已同步改名，详见 [course_structure.md](course_structure.md) §2.6。

第 7、9、10、12 次课（按变更前旧编号）已按 2026-08-29 合并方案完成正文精简改写（原始未合并素材 `docs/week07`、`week08`、`week10`、`week11`、`week12`、`week13`、`docs/13`、`docs/14` 已比对完毕并于 2026-08-30 清理，不再保留）。第 11 次课已从零新写完成，代码（定时器中断，`exception_entry` 升级为完整寄存器保存）与讲义/实验指导书均已实测通过。**全部 12 次课资料至此撰写完毕。**

## 稳定代码 tag（已发布 / 规划）

| tag | 对应课次 |
|---|---|
| `01-qemu-hello`（及 `01-00`–`01-03` 检查点） | 第 1 次课（已发布） |
| `02-data-bss` | 第 2 次课（已发布） |
| `03-regs-alu` | 第 3 次课（已发布） |
| `04-load-store` | 第 4 次课（已发布） |
| `05-branch-loop` | 第 5 次课（已发布） |
| `06-stack-abi` | 第 6 次课（已发布） |
| `07-libc-asm` | 第 7 次课（已发布，原 `08-libc-asm` 改名） |
| `08-uart-syscall` | 第 8 次课（已发布，原 `09-uart-syscall` 改名） |
| `09-trap-irq` | 第 9 次课（已发布，原 `10-trap-irq` 改名） |
| `10-build-debug` | 第 10 次课（已发布，原 `07-build-debug` 改名并改指向 `09-trap-irq` 同一提交） |
| `11-irq-kernel-recap` | 第 11 次课（已发布） |
| `12-board-agent-demo` | 第 12 次课（已发布，与 `11-irq-kernel-recap` 同一代码） |

## 阅读建议

1. 备课先读 [course_structure.md](course_structure.md)
2. 按课次打开 `NN/lecture_notes.md`
3. 遇到汇编块，按讲义“逐条讲解”组织课堂停顿

## 实验指导书与 PDF

每次课目录下同时提供：

- lab.md / NN_lab.pdf：实验指导书
- lecture_notes.md / NN_lecture_notes.pdf：教师讲义

批量生成实验：python scripts/generate_all_labs.py

批量转 PDF：python scripts/md_to_pdf.py

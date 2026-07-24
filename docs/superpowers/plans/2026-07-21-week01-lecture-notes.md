# Week 01 Lecture Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a complete teacher-facing Week 01 lecture note for QEMU Hello miniOS.

**Architecture:** Write a single Markdown lecture note that expands the PPT outline into a teachable script. It references existing code paths and docs without changing runtime code.

**Tech Stack:** Markdown, LoongArch64 miniOS source references.

## Global Constraints

- Output file must be exactly `docs/week01_qemu_hello_lecture_notes.md`.
- Expected output must be exactly `Hello miniOS on LoongArch64`.
- Week 01 focuses on `CPU -> boot/start.S -> kernel_main() -> printk() -> UART -> Hello miniOS`.
- `.data/.bss`, `clear_bss`, `memset`, `memcpy`, and `strlen` are only Week 02 preview or current-master context.
- AI co-learning is explanation-only in Week 01 and must not generate lab code.

---

### Task 1: Write Lecture Note

**Files:**
- Create: `docs/week01_qemu_hello_lecture_notes.md`

**Interfaces:**
- Consumes: `docs/week01_qemu_hello.md`, `docs/week01_qemu_hello_course.pptx`, `boot/start.S`, `kernel/main.c`, `kernel/printk.c`, `include/uart.h`, `Makefile`.
- Produces: complete teacher-facing lecture note.

- [ ] **Step 1: Create the lecture note**

The document must contain these top-level sections:

```markdown
# 第 1 周讲义：从 0 启动一个 LoongArch miniOS
## 1. 本周课程定位
## 2. 教学目标
## 3. 课前准备
## 4. 第 1 节：为什么学习汇编
## 5. 第 2 节：LoongArch 最小知识包
## 6. 第 3 节：从 C 到 ELF
## 7. 第 4 节：QEMU Hello miniOS 实验
## 8. 课堂 Demo 脚本
## 9. 学生实验任务
## 10. AI 共学边界
## 11. 常见问题与讲解口径
## 12. 板书建议
## 13. 思考题参考答案
## 14. 本周收束
```

- [ ] **Step 2: Include required code path**

The lecture note must include:

```text
CPU -> boot/start.S -> kernel_main() -> printk() -> UART -> Hello miniOS
```

- [ ] **Step 3: Include expected output**

The lecture note must include:

```text
Hello miniOS on LoongArch64
```

### Task 2: Verify Lecture Note

**Files:**
- Verify: `docs/week01_qemu_hello_lecture_notes.md`

**Interfaces:**
- Consumes: created lecture note.
- Produces: static verification evidence.

- [ ] **Step 1: Check required terms**

Run:

```powershell
rg -n "Hello miniOS on LoongArch64|boot/start\.S|kernel_main|printk|UART|AI 共学|不允许.*生成实验代码" docs\week01_qemu_hello_lecture_notes.md
```

Expected: Every required teaching term appears.

- [ ] **Step 2: Check stale strings**

Run:

```powershell
rg -n "Hello, LoongArch miniOS|miniOS booting" docs\week01_qemu_hello_lecture_notes.md
```

Expected: No matches.

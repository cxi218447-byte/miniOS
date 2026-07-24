# Week 01 Self-Study Handbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand `docs/week01_qemu_hello.md` into a standalone student self-study handbook for Week 01 QEMU Hello miniOS.

**Architecture:** Keep one canonical Week 01 handout and replace the current concise note with a fuller ordered guide. The guide remains documentation-only and preserves the Week 01 boundary around the Hello startup path.

**Tech Stack:** Markdown, PowerShell text checks, Git.

## Global Constraints

- Modify only `docs/week01_qemu_hello.md` unless verification reveals a broken link caused by this change.
- Focus on `CPU -> boot/start.S -> kernel_main() -> printk() -> UART -> Hello miniOS`.
- Do not ask students to generate or rewrite experiment code.
- Mention that current `master` may include Week 02 `.data/.bss` output, but exclude it from Week 01 acceptance.
- Preserve the expected Week 01 output exactly: `Hello miniOS on LoongArch64`.
- Keep the AI boundary explicit: AI may explain code and draw flowcharts, but may not directly generate the experiment code.

---

## File Structure

- Modify: `docs/week01_qemu_hello.md`
  - Responsibility: Student-facing self-study handbook for Week 01.
  - Must include preparation, directory tour, environment check, build/run steps, startup-source reading, command explanation, common errors, acceptance criteria, report template, AI rules, and thinking questions.

## Task 1: Rewrite Week 01 Handbook

**Files:**
- Modify: `docs/week01_qemu_hello.md`

**Interfaces:**
- Consumes: Existing Week 01 scope and the design in `docs/superpowers/specs/2026-07-24-week01-self-study-handbook-design.md`.
- Produces: A complete Markdown handout whose section headings and required markers can be checked by text search.

- [ ] **Step 1: Read current handout**

Run:

```powershell
Get-Content -Raw -Encoding UTF8 'docs\week01_qemu_hello.md'
```

Expected: The file is the current concise Week 01 experiment note and contains `Hello miniOS on LoongArch64`.

- [ ] **Step 2: Replace content with self-study handbook**

Use `apply_patch` to replace `docs/week01_qemu_hello.md` with a Markdown document containing these exact top-level sections:

```markdown
# 第 1 周实验指导手册：QEMU Hello miniOS

## 1. 实验定位
## 2. 学习目标
## 3. 实验前准备
## 4. 工程目录导览
## 5. 环境检查
## 6. 编译 miniOS
## 7. 运行 QEMU
## 8. 退出 QEMU
## 9. 启动路径总览
## 10. 阅读 boot/start.S
## 11. 阅读 kernel/main.c
## 12. 阅读 printk 与 UART 输出
## 13. 常用命令解释
## 14. 常见错误与处理
## 15. 实验验收标准
## 16. 实验报告模板
## 17. AI 共学要求
## 18. 思考题
## 19. 拓展阅读
```

Content requirements:

- Include the exact startup path:

```text
CPU
 ↓
boot/start.S
 ↓
kernel_main()
 ↓
printk()
 ↓
UART
 ↓
Hello miniOS
```

- Include these exact commands in fenced code blocks:

```bash
sh scripts/check-env.sh
make clean
make
make run
loongarch64-linux-gnu-objdump -d build/minios.elf | less
make debug
```

- Include the exact expected Week 01 output:

```text
Hello miniOS on LoongArch64
```

- Include this exact AI boundary sentence:

```text
不允许让 AI 直接生成实验代码。
```

- Include a report template with fields for:
  - 实验环境
  - 环境检查结果
  - 编译结果
  - QEMU 运行结果
  - 源码阅读记录
  - 错误与解决过程
  - AI 使用记录
  - 思考题回答

- [ ] **Step 3: Verify required markers**

Run:

```powershell
Select-String -Path 'docs\week01_qemu_hello.md' -Pattern 'Hello miniOS on LoongArch64|boot/start\.S|kernel_main|printk|UART|sh scripts/check-env\.sh|make clean|make run|objdump|make debug|实验报告模板|不允许让 AI 直接生成实验代码'
```

Expected: Output includes at least one match for every pattern listed in the command.

- [ ] **Step 4: Verify section order manually**

Run:

```powershell
Select-String -Path 'docs\week01_qemu_hello.md' -Pattern '^## '
```

Expected: The heading list appears in numeric order from `## 1. 实验定位` through `## 19. 拓展阅读`.

- [ ] **Step 5: Review Week 01 scope**

Run:

```powershell
Select-String -Path 'docs\week01_qemu_hello.md' -Pattern '\.data|\.bss|异常|中断|系统调用|2K0300'
```

Expected: `.data/.bss` appears only as a note that current `master` may show later-week output, not as Week 01 acceptance. `异常`, `中断`, `系统调用`, and `2K0300` do not appear as required Week 01 tasks.

- [ ] **Step 6: Check git diff**

Run:

```powershell
git diff -- docs/week01_qemu_hello.md
```

Expected: Diff only changes the Week 01 handout and does not introduce unrelated file edits.

- [ ] **Step 7: Commit handbook update**

Run:

```bash
git add docs/week01_qemu_hello.md
git commit -m "Expand week01 self-study handbook"
```

Expected: Git creates one commit for the handbook update.

## Self-Review Notes

- Spec coverage: Task 1 implements every section and required marker from `2026-07-24-week01-self-study-handbook-design.md`.
- Placeholder scan: This plan contains no `TBD`, `TODO`, or unspecified implementation steps.
- Type consistency: Not applicable; this is a documentation-only change.

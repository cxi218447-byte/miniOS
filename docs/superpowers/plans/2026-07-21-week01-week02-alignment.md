# Week 01-02 Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align Week 01-02 code and documents with the latest course-focused `AGENTS.md`.

**Architecture:** Keep the current branch as a combined Week 01-02 verification version. The runtime code emits one aligned Week 01 Hello line followed by Week 02 data and bss checks, while separate docs explain the Week 01 minimal path and Week 02 additions.

**Tech Stack:** LoongArch64 bare-metal C/assembly, GNU Make, QEMU `virt`, Markdown teaching docs.

## Global Constraints

- Runtime output for Week 01 Hello must use exactly `Hello miniOS on LoongArch64`.
- Do not mark build or QEMU verification as passed unless commands are actually run.
- Week 01 AI usage is explanation-only and must not generate lab code.
- Keep changes scoped to Week 01-02 code and teaching documents.
- Do not modify unrelated existing workspace changes.

---

### Task 1: Align Runtime Output

**Files:**
- Modify: `kernel/main.c`

**Interfaces:**
- Consumes: `printk(const char *s)`, `memset`, `memcpy`, `strlen`.
- Produces: Serial output lines used by README and docs.

- [ ] **Step 1: Inspect the current output strings**

Run: `Select-String -Path 'kernel\main.c' -Pattern 'Hello|miniOS booting|week1-week2|data section|bss section'`

Expected: Shows the old Hello string and `miniOS booting...`.

- [ ] **Step 2: Update `kernel/main.c`**

Change `kernel_main()` so the first two output calls are:

```c
    const char *msg = "Hello miniOS on LoongArch64\n";

    printk(msg);
```

Remove the line:

```c
    printk("miniOS booting...\n");
```

- [ ] **Step 3: Verify strings statically**

Run: `rg -n "Hello, LoongArch miniOS|miniOS booting|Hello miniOS on LoongArch64" kernel\main.c`

Expected: Only `Hello miniOS on LoongArch64` appears.

---

### Task 2: Add Week 01 Teaching Document

**Files:**
- Create: `docs/week01_qemu_hello.md`

**Interfaces:**
- Consumes: `boot/start.S`, `kernel/main.c`, `kernel/printk.c`, `include/uart.h`, `Makefile`.
- Produces: Student-facing Week 01 experiment guide.

- [ ] **Step 1: Create `docs/week01_qemu_hello.md`**

Use this structure:

```markdown
# 第 1 周实验：QEMU Hello miniOS

## 1. 实验目标

## 2. 背景知识

## 3. 核心路径

## 4. 关键文件

## 5. 编译与运行

## 6. 预期输出

## 7. AI 共学边界

## 8. 思考题
```

- [ ] **Step 2: Fill exact expected output**

The expected output block must be:

```text
Hello miniOS on LoongArch64
```

- [ ] **Step 3: Verify Week 01 doc terms**

Run: `rg -n "Hello miniOS on LoongArch64|boot/start.S|printf|AI|生成实验代码" docs\week01_qemu_hello.md`

Expected: Shows the aligned output, actual startup file, `printf` explanation, and AI boundary.

---

### Task 3: Add Week 02 Teaching Document

**Files:**
- Create: `docs/week02_data_bss.md`

**Interfaces:**
- Consumes: `boot/start.S`, `kernel/main.c`, `lib/string.S`, `include/string.h`, `kernel/linker.ld`.
- Produces: Student-facing Week 02 experiment guide.

- [ ] **Step 1: Create `docs/week02_data_bss.md`**

Use this structure:

```markdown
# 第 2 周实验：.data/.bss 与内存初始化

## 1. 实验目标

## 2. 背景知识

## 3. 从第 1 周到第 2 周

## 4. 关键代码

## 5. 编译与运行

## 6. 预期输出

## 7. 常见错误

## 8. 思考题
```

- [ ] **Step 2: Fill combined expected output**

The expected output block must be:

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

- [ ] **Step 3: Verify Week 02 doc terms**

Run: `rg -n "\.data|\.bss|clear_bss|memset|memcpy|strlen|week1-week2" docs\week02_data_bss.md`

Expected: Shows every Week 02 concept.

---

### Task 4: Update README and Release Index

**Files:**
- Modify: `README.md`
- Modify: `docs/course_release_index.md`

**Interfaces:**
- Consumes: Week 01 and Week 02 document paths.
- Produces: Repository entry points that point to the new weekly docs.

- [ ] **Step 1: Update README links**

Add links near the current Week 01-02 description:

```markdown
- 第 1 周实验文档：[docs/week01_qemu_hello.md](docs/week01_qemu_hello.md)
- 第 2 周实验文档：[docs/week02_data_bss.md](docs/week02_data_bss.md)
```

- [ ] **Step 2: Update release index document references**

Add a `实验文档` column or equivalent text so Week 01 points to `docs/week01_qemu_hello.md` and Week 02 points to `docs/week02_data_bss.md`.

Keep release and test statuses conservative: no `已测试通过` unless real commands were run.

- [ ] **Step 3: Verify links and statuses**

Run: `rg -n "week01_qemu_hello|week02_data_bss|已测试通过|待确认|未执行" README.md docs\course_release_index.md`

Expected: README links exist; Week 01 remains `待确认`; Week 02 remains `未执行`.

---

### Task 5: Static Verification

**Files:**
- Read-only verification across repository.

**Interfaces:**
- Consumes: All edited files.
- Produces: Evidence for final response.

- [ ] **Step 1: Search for stale output in teaching docs and code**

Run: `rg -n "Hello, LoongArch miniOS|miniOS booting" kernel docs README.md`

Expected: No matches, except historical design/plan text if included under `docs/superpowers`.

- [ ] **Step 2: Search for aligned output**

Run: `rg -n "Hello miniOS on LoongArch64" kernel docs README.md AGENTS.md`

Expected: Matches in `kernel/main.c`, README, Week 01 doc, Week 02 doc, WSL install doc, porting guide, PPT-generated text if searchable, and AGENTS.

- [ ] **Step 3: Check git diff**

Run: `git diff --stat`

Expected: Shows only intended code/doc changes plus pre-existing workspace changes.

- [ ] **Step 4: Record verification limitation**

If `make`, `qemu-system-loongarch64`, or `loongarch64-linux-gnu-gcc` are unavailable, final response must state that build/QEMU verification was not run.

# Week 01 Course PPT Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a clean Week 01 classroom PPT for QEMU Hello miniOS.

**Architecture:** Add a new Python generator instead of repairing the existing mojibake script. The generator uses `python-pptx` helpers for title, bullet, flow, and code slides, then writes `docs/week01_qemu_hello_course.pptx`.

**Tech Stack:** Python 3, `python-pptx`, PowerShell validation, PPTX zip text extraction.

## Global Constraints

- New PPT path must be exactly `docs/week01_qemu_hello_course.pptx`.
- New generator path must be exactly `scripts/generate_week01_course_ppt.py`.
- Expected Week 01 output must be exactly `Hello miniOS on LoongArch64`.
- Stale strings `Hello, LoongArch miniOS` and `miniOS booting` must not appear in the new PPT.
- Week 01 must mention `.data/.bss` only as Week 02 preview or current-master context.

---

### Task 1: Create Clean Generator

**Files:**
- Create: `scripts/generate_week01_course_ppt.py`

**Interfaces:**
- Consumes: `docs/week01_qemu_hello.md` and current repository paths.
- Produces: `docs/week01_qemu_hello_course.pptx`.

- [ ] **Step 1: Write generator script**

Create `scripts/generate_week01_course_ppt.py` with helper functions:

```python
def add_title(slide, heading, subtitle=None, lesson=None): ...
def add_bullet_slide(prs, heading, items, subtitle=None, lesson=None): ...
def add_code_slide(prs, heading, code_text, subtitle=None, lesson=None, font_size=14): ...
def add_flow_slide(prs, heading, steps, subtitle=None, lesson=None): ...
def build(): ...
```

- [ ] **Step 2: Include 4-lesson outline**

The deck must include these sections:

```text
第 1 节：为什么学习汇编
第 2 节：LoongArch 最小知识包
第 3 节：从 C 到可执行文件
第 4 节：QEMU Hello miniOS 实验
```

- [ ] **Step 3: Include required output**

The deck must include:

```text
Hello miniOS on LoongArch64
```

---

### Task 2: Generate PPT

**Files:**
- Create: `docs/week01_qemu_hello_course.pptx`

**Interfaces:**
- Consumes: `scripts/generate_week01_course_ppt.py`.
- Produces: non-empty PPTX.

- [ ] **Step 1: Run generator**

Run: `python scripts\generate_week01_course_ppt.py`

Expected: Prints the PPT path and slide count.

- [ ] **Step 2: Confirm file exists**

Run: `Get-Item docs\week01_qemu_hello_course.pptx | Select-Object FullName,Length`

Expected: File exists and `Length` is greater than 0.

---

### Task 3: Verify PPT Text

**Files:**
- Verify: `docs/week01_qemu_hello_course.pptx`

**Interfaces:**
- Consumes: generated PPTX.
- Produces: text verification evidence.

- [ ] **Step 1: Extract slide text**

Run a PowerShell zip extraction over `ppt/slides/slide*.xml`.

Expected: Text extraction succeeds.

- [ ] **Step 2: Check required and stale strings**

Required:

```text
Hello miniOS on LoongArch64
boot/start.S
AI 共学边界
```

Forbidden:

```text
Hello, LoongArch miniOS
miniOS booting
```

- [ ] **Step 3: Check git status**

Run: `git status --short`

Expected: Shows the new script and PPT plus existing uncommitted course-alignment changes.

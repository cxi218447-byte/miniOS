# Docs Week Directory Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move generated weekly course materials under `docs/week01/` and `docs/week02/` and update user-facing links.

**Architecture:** Keep cross-week docs at top level and move only course-facing weekly files/directories. Update README, release index, and moved handbook relative links so students have stable entry points.

**Tech Stack:** Markdown, PowerShell file operations, Git.

## Global Constraints

- Do not move `docs/superpowers/`.
- Do not change code or generated build outputs.
- Preserve Week 01 and Week 02 document content except for relative path fixes.
- Do not touch unrelated dirty workspace files.

---

## File Structure

- Move: `docs/week01_qemu_hello.md` -> `docs/week01/qemu_hello.md`
- Move: `docs/week01_slide15_build_pipeline_animation/` -> `docs/week01/slide15_build_pipeline_animation/`
- Move: `docs/week02_data_bss.md` -> `docs/week02/data_bss.md`
- Modify: `README.md`
- Modify: `docs/course_release_index.md`
- Modify: `docs/week01/qemu_hello.md`

## Task 1: Move Weekly Course Materials

**Files:**
- Create directory: `docs/week01/`
- Create directory: `docs/week02/`
- Move: `docs/week01_qemu_hello.md` -> `docs/week01/qemu_hello.md`
- Move: `docs/week01_slide15_build_pipeline_animation/` -> `docs/week01/slide15_build_pipeline_animation/`
- Move: `docs/week02_data_bss.md` -> `docs/week02/data_bss.md`

**Interfaces:**
- Consumes: Existing top-level weekly docs.
- Produces: Week-based course material layout.

- [ ] **Step 1: Create week directories**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'docs\week01','docs\week02'
```

Expected: Both directories exist.

- [ ] **Step 2: Move files and animation directory**

Run:

```powershell
Move-Item -LiteralPath 'docs\week01_qemu_hello.md' -Destination 'docs\week01\qemu_hello.md'
Move-Item -LiteralPath 'docs\week01_slide15_build_pipeline_animation' -Destination 'docs\week01\slide15_build_pipeline_animation'
Move-Item -LiteralPath 'docs\week02_data_bss.md' -Destination 'docs\week02\data_bss.md'
```

Expected: Old paths no longer exist; new paths exist.

- [ ] **Step 3: Verify new paths**

Run:

```powershell
Test-Path 'docs\week01\qemu_hello.md'
Test-Path 'docs\week01\slide15_build_pipeline_animation\index.html'
Test-Path 'docs\week02\data_bss.md'
```

Expected: All three commands print `True`.

## Task 2: Update User-Facing Links

**Files:**
- Modify: `README.md`
- Modify: `docs/course_release_index.md`
- Modify: `docs/week01/qemu_hello.md`

**Interfaces:**
- Consumes: New week-based paths from Task 1.
- Produces: Working user-facing links to moved files.

- [ ] **Step 1: Update README links**

In `README.md`, replace:

```text
docs/week01_qemu_hello.md
docs/week02_data_bss.md
```

with:

```text
docs/week01/qemu_hello.md
docs/week02/data_bss.md
```

- [ ] **Step 2: Update release index links**

In `docs/course_release_index.md`, replace:

```text
[docs/week01_qemu_hello.md](week01_qemu_hello.md)
[docs/week02_data_bss.md](week02_data_bss.md)
```

with:

```text
[docs/week01/qemu_hello.md](week01/qemu_hello.md)
[docs/week02/data_bss.md](week02/data_bss.md)
```

Also update the release workflow comment:

```text
docs/weekXX_*.md
```

to:

```text
docs/weekXX/*.md
```

- [ ] **Step 3: Update moved Week 01 handbook relative links**

In `docs/week01/qemu_hello.md`, replace top-level doc references:

```text
docs/manual_wsl_ubuntu_install.md
docs/environment_check.md
docs/course_release_index.md
docs/QEMU-to-Loongson-Pioneer-Porting-Guide.md
```

with:

```text
../manual_wsl_ubuntu_install.md
../environment_check.md
../course_release_index.md
../QEMU-to-Loongson-Pioneer-Porting-Guide.md
```

## Task 3: Verify References and Commit

**Files:**
- Verify: `README.md`
- Verify: `docs/course_release_index.md`
- Verify: `docs/week01/qemu_hello.md`
- Verify: `docs/week01/slide15_build_pipeline_animation/*`
- Verify: `docs/week02/data_bss.md`

**Interfaces:**
- Consumes: Moved files and updated links.
- Produces: One commit containing the reorganization.

- [ ] **Step 1: Search for old course-facing paths**

Run:

```powershell
if (Get-Command rg -ErrorAction SilentlyContinue) { rg -n "docs/week01_qemu_hello.md|docs/week02_data_bss.md|docs/week01_slide15_build_pipeline_animation|week01_qemu_hello.md|week02_data_bss.md|week01_slide15_build_pipeline_animation" README.md docs --glob '!docs/superpowers/**' } else { Get-ChildItem -Recurse -File README.md,docs | Where-Object { $_.FullName -notlike '*\docs\superpowers\*' } | Select-String -Pattern 'docs/week01_qemu_hello.md|docs/week02_data_bss.md|docs/week01_slide15_build_pipeline_animation|week01_qemu_hello.md|week02_data_bss.md|week01_slide15_build_pipeline_animation' }
```

Expected: No output.

- [ ] **Step 2: Search for new links**

Run:

```powershell
Select-String -Path 'README.md','docs\course_release_index.md','docs\week01\qemu_hello.md' -Pattern 'docs/week01/qemu_hello.md|docs/week02/data_bss.md|week01/qemu_hello.md|week02/data_bss.md|\.\./manual_wsl_ubuntu_install.md|\.\./environment_check.md|\.\./course_release_index.md|\.\./QEMU-to-Loongson-Pioneer-Porting-Guide.md'
```

Expected: Output includes matches for README links, release index links, and moved Week 01 relative links.

- [ ] **Step 3: Check staged file set**

Run:

```powershell
git status --short
```

Expected: Reorganization changes are limited to moved weekly docs, moved Week 01 animation directory, `README.md`, and `docs/course_release_index.md`, while unrelated pre-existing dirty files may still appear.

- [ ] **Step 4: Commit reorganization**

Run:

```bash
git add README.md docs/course_release_index.md docs/week01 docs/week02
git commit -m "Organize docs by teaching week"
```

Expected: Git creates one commit for the docs reorganization.

## Self-Review Notes

- Spec coverage: Tasks move all scoped weekly materials and update user-facing links.
- Placeholder scan: No unspecified steps remain.
- Type consistency: Not applicable; this is a file organization change.

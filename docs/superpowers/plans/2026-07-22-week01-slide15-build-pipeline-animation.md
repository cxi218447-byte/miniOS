# Week 01 Slide 15 Build Pipeline Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an offline web animation that explains the real miniOS build pipeline from source files to QEMU output.

**Architecture:** Create a static HTML/CSS/JavaScript artifact under `docs/week01_slide15_build_pipeline_animation/`. The page uses one continuous "实验桌流水线" with tangible objects: source files, compiler, object files, linker script, ELF file, and QEMU terminal. JavaScript drives a seven-step player and exposes `window.slide15Animation` for smoke tests.

**Tech Stack:** Plain HTML5, CSS3, and browser JavaScript. No backend, package manager, CDN, or network dependency.

## Global Constraints

- The page must work offline by directly opening `docs/week01_slide15_build_pipeline_animation/index.html`.
- The animation must use real repository paths and tool names: `kernel/main.c`, `boot/start.S`, `include/*.h`, `loongarch64-linux-gnu-gcc`, `build/kernel/main.o`, `build/boot/start.o`, `kernel/linker.ld`, `build/minios.elf`, `qemu-system-loongarch64`.
- The final output must include `Hello miniOS on LoongArch64`.
- The visual model must be one continuous build pipeline, not a three-column abstract panel layout.
- Controls must include play/pause, previous, next, clickable step markers, and keyboard support.
- Do not add external JavaScript, CSS, images, fonts, or network calls.
- In the current dirty workspace, do not commit automatically. Stage/commit only after the user explicitly asks.

---

## File Structure

- Create: `docs/week01_slide15_build_pipeline_animation/index.html`
  - Static page shell, tangible pipeline objects, answer area, and controls.
- Create: `docs/week01_slide15_build_pipeline_animation/styles.css`
  - Projection-readable layout, pipeline object visuals, step states, and responsive behavior.
- Create: `docs/week01_slide15_build_pipeline_animation/app.js`
  - Seven-step state machine, render function, controls, keyboard handlers, and smoke-test API.

---

### Task 1: Static Pipeline Markup

**Files:**
- Create: `docs/week01_slide15_build_pipeline_animation/index.html`

**Interfaces:**
- Produces DOM IDs: `app`, `questionText`, `answerText`, `commandText`, `sourceFiles`, `compilerTool`, `objectFiles`, `linkerTool`, `elfFile`, `qemuWindow`, `terminalOutput`, `playPause`, `prevStep`, `nextStep`, `stepMarkers`.
- Produces data attributes: `data-stage="source"`, `data-stage="compile"`, `data-stage="objects"`, `data-stage="link"`, `data-stage="elf"`, `data-stage="qemu"`.

- [ ] **Step 1: Create directory and HTML**

Create a semantic offline page with:

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>第 1 周第 15 页：编译流程解答</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <main id="app" class="lesson-shell" data-step="0">
    <header class="lesson-header">
      <p class="eyebrow">第 3 节 · 第 15 页解答动画</p>
      <h1>make 到底把源文件变成了什么？</h1>
      <p id="questionText" class="question">.c/.S 不是直接运行的程序，QEMU 最后加载的是什么？</p>
    </header>
    <section class="workbench" aria-label="miniOS 编译运行流水线">
      <article id="sourceFiles" class="stage-object source-object" data-stage="source">...</article>
      <div class="pipeline-arrow" aria-hidden="true">→</div>
      <article id="compilerTool" class="stage-object tool-object" data-stage="compile">...</article>
      <div class="pipeline-arrow" aria-hidden="true">→</div>
      <article id="objectFiles" class="stage-object build-object" data-stage="objects">...</article>
      <div class="pipeline-arrow" aria-hidden="true">→</div>
      <article id="linkerTool" class="stage-object linker-object" data-stage="link">...</article>
      <div class="pipeline-arrow" aria-hidden="true">→</div>
      <article id="elfFile" class="stage-object elf-object" data-stage="elf">...</article>
      <div class="pipeline-arrow" aria-hidden="true">→</div>
      <article id="qemuWindow" class="stage-object qemu-object" data-stage="qemu">...</article>
    </section>
    <section class="detail-strip" aria-live="polite">
      <pre id="commandText">make</pre>
      <p id="answerText">先看工程里的真实文件。</p>
    </section>
    <footer class="controls" aria-label="动画控制">
      <button id="prevStep" type="button" aria-label="上一步">◀</button>
      <button id="playPause" type="button" aria-label="播放">播放</button>
      <button id="nextStep" type="button" aria-label="下一步">▶</button>
      <div id="stepMarkers" class="step-markers" aria-label="步骤导航"></div>
    </footer>
  </main>
  <script src="app.js"></script>
</body>
</html>
```

- [ ] **Step 2: Verify file exists**

Run:

```powershell
Test-Path 'docs\week01_slide15_build_pipeline_animation\index.html'
```

Expected: `True`

---

### Task 2: Pipeline Visual States

**Files:**
- Create: `docs/week01_slide15_build_pipeline_animation/styles.css`

**Interfaces:**
- Consumes DOM IDs and `data-stage` attributes from Task 1.
- Produces stable layout and `[data-step="0"]` through `[data-step="6"]` visual states.

- [ ] **Step 1: Create CSS**

Use CSS to build tangible objects:

- Folder and paper sheets for source files.
- Tool/machine block for compiler.
- Build folder and `.o` file sheets.
- Linker station with `kernel/linker.ld`.
- ELF file sheet.
- QEMU terminal window.

Step states must progressively highlight:

```text
0: source
1: source + headers
2: compiler + object files
3: object files
4: linker + linker.ld
5: ELF
6: QEMU terminal output
```

- [ ] **Step 2: Verify no external dependencies**

Run:

```powershell
Select-String -Path 'docs\week01_slide15_build_pipeline_animation\*.html','docs\week01_slide15_build_pipeline_animation\*.css','docs\week01_slide15_build_pipeline_animation\*.js' -Pattern 'https?://|cdn|npm|unpkg'
```

Expected: no matches.

---

### Task 3: Step Player Logic

**Files:**
- Create: `docs/week01_slide15_build_pipeline_animation/app.js`

**Interfaces:**
- Consumes IDs from Task 1.
- Produces:

```javascript
window.slide15Animation = {
  goToStep(index),
  next(),
  previous(),
  play(),
  pause(),
  getCurrentStep()
}
```

- [ ] **Step 1: Create seven step definitions**

Each step must include:

```javascript
{
  question: string,
  command: string,
  answer: string,
  terminal: string
}
```

The final step must set terminal output to:

```text
Hello miniOS on LoongArch64
```

- [ ] **Step 2: Add controls**

Implement play/pause, previous, next, marker click, left arrow, right arrow, and space key.

- [ ] **Step 3: Verify JS syntax**

Run:

```powershell
node --check docs\week01_slide15_build_pipeline_animation\app.js
```

Expected: exit code 0.

---

### Task 4: Verification

**Files:**
- Verify: `docs/week01_slide15_build_pipeline_animation/index.html`
- Verify: `docs/week01_slide15_build_pipeline_animation/styles.css`
- Verify: `docs/week01_slide15_build_pipeline_animation/app.js`

- [ ] **Step 1: Check required files**

Run:

```powershell
Get-ChildItem 'docs\week01_slide15_build_pipeline_animation' | Select-Object Name,Length
```

Expected: `index.html`, `styles.css`, and `app.js` exist and have non-zero length.

- [ ] **Step 2: Check required teaching copy**

Run:

```powershell
Select-String -Path 'docs\week01_slide15_build_pipeline_animation\*.*' -Pattern 'kernel/main.c|boot/start.S|loongarch64-linux-gnu-gcc|kernel/linker.ld|build/minios.elf|qemu-system-loongarch64|Hello miniOS on LoongArch64'
```

Expected: each required string appears at least once.

- [ ] **Step 3: Browser screenshot**

Open `index.html` with headless Chrome using a `file:///` URI and capture a screenshot.

Expected: screenshot is non-empty and shows the workbench pipeline plus bottom controls.

- [ ] **Step 4: Browser interaction smoke test**

Use Chrome remote debugging or manual browser interaction to call:

```javascript
window.slide15Animation.goToStep(6)
```

Expected:

```json
{"step":6,"terminal":"Hello miniOS on LoongArch64"}
```

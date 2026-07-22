# Week 01 Slide 8 C-to-CPU Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an offline single-page web animation that explains how `int add(int a, int b) { return a + b; }` becomes register-level CPU execution.

**Architecture:** Create a static HTML/CSS/JavaScript artifact under `docs/week01_slide8_c_to_cpu_animation/`. `index.html` owns the semantic teaching structure, `styles.css` owns layout and animation states, and `app.js` owns the step-player state machine.

**Tech Stack:** Plain HTML5, CSS3, and browser JavaScript. No backend, no package manager, no network dependencies.

## Global Constraints

- The page must work offline by opening `docs/week01_slide8_c_to_cpu_animation/index.html`.
- The page must support classroom projection and student self-study.
- Controls must include play/pause, previous, next, and clickable step markers.
- The animation must teach `变量名 -> 参数位置 -> 寄存器`.
- The example call is `add(3, 5)`.
- The simplified instruction is `add.w r4, r4, r5`.
- The register convention shown is `参数1 -> r4`, `参数2 -> r5`, `返回值 -> r4`.
- Do not add external JavaScript or CSS dependencies.

---

## File Structure

- Create: `docs/week01_slide8_c_to_cpu_animation/index.html`
  - Static document shell, teaching panels, controls, and accessible labels.
- Create: `docs/week01_slide8_c_to_cpu_animation/styles.css`
  - Responsive three-zone layout, code/register visuals, animation transitions, and control styling.
- Create: `docs/week01_slide8_c_to_cpu_animation/app.js`
  - Step definitions, render function, playback timer, button handlers, keyboard handlers, and smoke-test hooks.

---

### Task 1: Static Teaching Markup

**Files:**
- Create: `docs/week01_slide8_c_to_cpu_animation/index.html`

**Interfaces:**
- Consumes: none.
- Produces:
  - DOM elements with these IDs: `app`, `codePanel`, `mappingLane`, `cpuPanel`, `summaryText`, `playPause`, `prevStep`, `nextStep`, `stepMarkers`.
  - DOM elements with these data attributes: `data-token="a"`, `data-token="b"`, `data-register="r4"`, `data-register="r5"`, `data-instruction`.

- [ ] **Step 1: Create the HTML file**

Create `docs/week01_slide8_c_to_cpu_animation/index.html` with:

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>第 1 周：从 C 代码到 CPU 执行</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <main id="app" class="lesson-shell" data-step="0">
    <header class="lesson-header">
      <p class="eyebrow">第 1 节 · 课堂互动</p>
      <h1>动手写一行代码，拆穿 CPU 的「魔术」</h1>
    </header>

    <section class="stage" aria-label="C 代码到 CPU 执行动画">
      <article id="codePanel" class="panel code-panel">
        <h2>C 代码</h2>
        <pre><code><span class="code-keyword">int</span> add(<span class="code-keyword">int</span> <span data-token="a">a</span>, <span class="code-keyword">int</span> <span data-token="b">b</span>) {
    <span class="code-keyword">return</span> <span data-token="a">a</span> + <span data-token="b">b</span>;
}</code></pre>
        <div class="callout" id="questionText">CPU 真的认识变量名 a 和 b 吗？</div>
      </article>

      <article id="mappingLane" class="panel mapping-panel">
        <h2>转换过程</h2>
        <div class="mapping-stack">
          <div class="mapping-row" data-map="name-a"><span>a</span><strong>变量名</strong></div>
          <div class="mapping-row" data-map="slot-a"><span>参数1</span><strong>调用约定</strong></div>
          <div class="mapping-row" data-map="reg-a"><span>r4</span><strong>寄存器</strong></div>
        </div>
        <div class="mapping-stack">
          <div class="mapping-row" data-map="name-b"><span>b</span><strong>变量名</strong></div>
          <div class="mapping-row" data-map="slot-b"><span>参数2</span><strong>调用约定</strong></div>
          <div class="mapping-row" data-map="reg-b"><span>r5</span><strong>寄存器</strong></div>
        </div>
      </article>

      <article id="cpuPanel" class="panel cpu-panel">
        <h2>CPU 执行</h2>
        <div class="register-board">
          <div class="register" data-register="r4"><span>r4</span><strong id="r4Value">?</strong></div>
          <div class="register" data-register="r5"><span>r5</span><strong id="r5Value">?</strong></div>
        </div>
        <pre class="instruction" data-instruction>等待指令</pre>
        <div class="result-flow" id="resultFlow">add(3, 5)</div>
      </article>
    </section>

    <section class="summary" aria-live="polite">
      <p id="summaryText">先观察一行最简单的 C 函数。</p>
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

- [ ] **Step 2: Open the file directly**

Run:

```powershell
Test-Path 'docs\week01_slide8_c_to_cpu_animation\index.html'
```

Expected: `True`

- [ ] **Step 3: Commit**

```bash
git add docs/week01_slide8_c_to_cpu_animation/index.html
git commit -m "feat: add slide8 animation markup"
```

---

### Task 2: Layout And Visual States

**Files:**
- Create: `docs/week01_slide8_c_to_cpu_animation/styles.css`

**Interfaces:**
- Consumes: HTML IDs and data attributes from Task 1.
- Produces:
  - Stable responsive layout for `.stage`, `.panel`, `.controls`.
  - Step-state classes driven by `body`/`#app` attribute selectors: `[data-step="0"]` through `[data-step="6"]`.

- [ ] **Step 1: Create the stylesheet**

Create `docs/week01_slide8_c_to_cpu_animation/styles.css` with:

```css
:root {
  color-scheme: light;
  --bg: #f6f8fb;
  --ink: #17202a;
  --muted: #596575;
  --panel: #ffffff;
  --line: #d8dee8;
  --code: #0f2438;
  --accent: #0b7285;
  --accent-2: #b7791f;
  --cpu: #24543f;
  --hot: #d9480f;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  min-height: 100vh;
  background: var(--bg);
  color: var(--ink);
  font-family: "Microsoft YaHei", "Segoe UI", sans-serif;
}

.lesson-shell {
  min-height: 100vh;
  padding: 28px clamp(18px, 3vw, 48px) 92px;
}

.lesson-header {
  max-width: 1180px;
  margin: 0 auto 18px;
}

.eyebrow {
  margin: 0 0 8px;
  color: var(--accent);
  font-weight: 700;
}

h1 {
  margin: 0;
  font-size: clamp(28px, 4vw, 52px);
  line-height: 1.12;
  letter-spacing: 0;
}

.stage {
  display: grid;
  grid-template-columns: minmax(280px, 1.05fr) minmax(260px, 0.9fr) minmax(280px, 1fr);
  gap: 16px;
  max-width: 1180px;
  margin: 0 auto;
  align-items: stretch;
}

.panel {
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 18px;
  min-height: 360px;
  box-shadow: 0 10px 24px rgba(23, 32, 42, 0.08);
}

.panel h2 {
  margin: 0 0 14px;
  font-size: 18px;
}

pre {
  margin: 0;
  white-space: pre-wrap;
}

.code-panel code {
  display: block;
  min-height: 160px;
  padding: 18px;
  border-radius: 8px;
  background: var(--code);
  color: #e8f1f8;
  font: 700 clamp(18px, 2.1vw, 27px) / 1.55 Consolas, "Courier New", monospace;
}

.code-keyword {
  color: #8ce99a;
}

[data-token] {
  border-radius: 4px;
  padding: 0 3px;
  transition: background-color 250ms ease, color 250ms ease, opacity 250ms ease;
}

.callout {
  margin-top: 18px;
  padding: 14px;
  border-left: 4px solid var(--accent);
  background: #e7f5f8;
  color: #12343b;
  font-size: 18px;
  font-weight: 700;
  line-height: 1.45;
}

.mapping-stack {
  display: grid;
  gap: 10px;
  margin-bottom: 18px;
}

.mapping-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  min-height: 58px;
  align-items: center;
  padding: 12px;
  border: 1px dashed var(--line);
  border-radius: 8px;
  opacity: 0.26;
  transform: translateY(6px);
  transition: opacity 260ms ease, transform 260ms ease, border-color 260ms ease, background-color 260ms ease;
}

.mapping-row span {
  font-size: 24px;
  font-weight: 800;
}

.mapping-row strong {
  color: var(--muted);
  font-size: 14px;
}

.register-board {
  display: grid;
  grid-template-columns: repeat(2, minmax(110px, 1fr));
  gap: 12px;
  margin-bottom: 18px;
}

.register {
  min-height: 112px;
  border-radius: 8px;
  border: 2px solid #bed3c7;
  background: #edf7f1;
  display: grid;
  place-items: center;
  transition: border-color 260ms ease, background-color 260ms ease, transform 260ms ease;
}

.register span {
  color: var(--cpu);
  font-weight: 800;
}

.register strong {
  font-size: 42px;
}

.instruction {
  min-height: 74px;
  padding: 16px;
  border-radius: 8px;
  background: #10251c;
  color: #d8f5df;
  font: 800 clamp(18px, 2vw, 26px) / 1.4 Consolas, "Courier New", monospace;
}

.result-flow {
  margin-top: 16px;
  min-height: 54px;
  padding: 14px;
  border-radius: 8px;
  background: #fff4e6;
  color: #7c3f00;
  font-size: 22px;
  font-weight: 800;
}

.summary {
  max-width: 1180px;
  margin: 18px auto 0;
  padding: 16px 18px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #ffffff;
  font-size: clamp(18px, 2vw, 24px);
  font-weight: 700;
  line-height: 1.45;
}

.summary p {
  margin: 0;
}

.controls {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  min-height: 70px;
  padding: 12px;
  background: rgba(255, 255, 255, 0.96);
  border-top: 1px solid var(--line);
}

button {
  min-width: 54px;
  min-height: 42px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #ffffff;
  color: var(--ink);
  font-weight: 800;
  cursor: pointer;
}

button:hover,
button:focus-visible {
  border-color: var(--accent);
  outline: none;
}

.step-markers {
  display: flex;
  gap: 8px;
  align-items: center;
}

.step-marker {
  width: 34px;
  height: 10px;
  min-width: 34px;
  min-height: 10px;
  padding: 0;
  border-radius: 999px;
  background: #d8dee8;
}

.step-marker.active {
  background: var(--accent);
}

[data-step="1"] [data-token],
[data-step="2"] [data-token] {
  background: #ffd43b;
  color: #17202a;
}

[data-step="2"] [data-map^="name"],
[data-step="3"] [data-map],
[data-step="4"] [data-map],
[data-step="5"] [data-map],
[data-step="6"] [data-map] {
  opacity: 1;
  transform: translateY(0);
  border-color: var(--accent);
}

[data-step="3"] [data-map^="reg"],
[data-step="4"] [data-map^="reg"],
[data-step="5"] [data-map^="reg"],
[data-step="6"] [data-map^="reg"] {
  background: #edf7f1;
  border-color: var(--cpu);
}

[data-step="4"] .register,
[data-step="5"] .register,
[data-step="6"] .register {
  border-color: var(--cpu);
  background: #dff3e6;
}

[data-step="5"] [data-register="r4"] {
  transform: scale(1.03);
  border-color: var(--hot);
}

@media (max-width: 920px) {
  .stage {
    grid-template-columns: 1fr;
  }

  .panel {
    min-height: auto;
  }

  .controls {
    flex-wrap: wrap;
  }
}
```

- [ ] **Step 2: Verify stylesheet exists**

Run:

```powershell
Test-Path 'docs\week01_slide8_c_to_cpu_animation\styles.css'
```

Expected: `True`

- [ ] **Step 3: Commit**

```bash
git add docs/week01_slide8_c_to_cpu_animation/styles.css
git commit -m "feat: style slide8 animation"
```

---

### Task 3: Step Player Logic

**Files:**
- Create: `docs/week01_slide8_c_to_cpu_animation/app.js`

**Interfaces:**
- Consumes:
  - `#app`, `#summaryText`, `#questionText`, `#playPause`, `#prevStep`, `#nextStep`, `#stepMarkers`, `#r4Value`, `#r5Value`, `[data-instruction]`, `#resultFlow`.
- Produces:
  - `window.slide8Animation` with methods `{ goToStep(index), next(), previous(), play(), pause(), getCurrentStep() }`.

- [ ] **Step 1: Create the JavaScript file**

Create `docs/week01_slide8_c_to_cpu_animation/app.js` with:

```javascript
(function () {
  const steps = [
    {
      question: "CPU 真的认识变量名 a 和 b 吗？",
      summary: "先观察一行最简单的 C 函数。",
      r4: "?",
      r5: "?",
      instruction: "等待指令",
      result: "add(3, 5)"
    },
    {
      question: "a 和 b 是写给谁看的？",
      summary: "变量名帮助程序员理解代码，但 CPU 不直接执行变量名。",
      r4: "?",
      r5: "?",
      instruction: "等待指令",
      result: "变量名：a、b"
    },
    {
      question: "如果去掉变量名，调用还剩下什么？",
      summary: "函数调用先关心参数位置：a 是参数1，b 是参数2。",
      r4: "?",
      r5: "?",
      instruction: "准备传参",
      result: "a -> 参数1；b -> 参数2"
    },
    {
      question: "参数进入 CPU 后放在哪里？",
      summary: "在这个教学例子中，参数1 放入 r4，参数2 放入 r5，返回值也放在 r4。",
      r4: "3",
      r5: "5",
      instruction: "参数1 -> r4；参数2 -> r5",
      result: "add(3, 5)"
    },
    {
      question: "return a + b 对 CPU 来说是什么动作？",
      summary: "CPU 执行加法指令，把 r4 和 r5 中的值相加。",
      r4: "3",
      r5: "5",
      instruction: "add.w r4, r4, r5",
      result: "r4(3) + r5(5)"
    },
    {
      question: "加法结果放在哪里返回？",
      summary: "加法结果写回 r4，所以 r4 从参数1的位置变成返回值的位置。",
      r4: "8",
      r5: "5",
      instruction: "add.w r4, r4, r5",
      result: "r4 = 8"
    },
    {
      question: "汇编帮助我们看见什么？",
      summary: "C 语言变量名是给人看的。CPU 执行的是寄存器、指令和数据流。汇编帮助我们看见 C 语言和机器执行之间的转换过程。",
      r4: "8",
      r5: "5",
      instruction: "return value in r4",
      result: "return 8"
    }
  ];

  const app = document.getElementById("app");
  const summaryText = document.getElementById("summaryText");
  const questionText = document.getElementById("questionText");
  const playPause = document.getElementById("playPause");
  const prevStep = document.getElementById("prevStep");
  const nextStep = document.getElementById("nextStep");
  const stepMarkers = document.getElementById("stepMarkers");
  const r4Value = document.getElementById("r4Value");
  const r5Value = document.getElementById("r5Value");
  const instruction = document.querySelector("[data-instruction]");
  const resultFlow = document.getElementById("resultFlow");

  let currentStep = 0;
  let timer = null;

  function renderMarkers() {
    stepMarkers.innerHTML = "";
    steps.forEach((step, index) => {
      const marker = document.createElement("button");
      marker.className = "step-marker";
      marker.type = "button";
      marker.setAttribute("aria-label", `第 ${index + 1} 步`);
      marker.addEventListener("click", () => goToStep(index));
      stepMarkers.appendChild(marker);
    });
  }

  function render() {
    const step = steps[currentStep];
    app.dataset.step = String(currentStep);
    questionText.textContent = step.question;
    summaryText.textContent = step.summary;
    r4Value.textContent = step.r4;
    r5Value.textContent = step.r5;
    instruction.textContent = step.instruction;
    resultFlow.textContent = step.result;
    prevStep.disabled = currentStep === 0;
    nextStep.disabled = currentStep === steps.length - 1;
    Array.from(stepMarkers.children).forEach((marker, index) => {
      marker.classList.toggle("active", index === currentStep);
      marker.setAttribute("aria-current", index === currentStep ? "step" : "false");
    });
  }

  function goToStep(index) {
    currentStep = Math.max(0, Math.min(steps.length - 1, index));
    render();
  }

  function next() {
    if (currentStep === steps.length - 1) {
      pause();
      return;
    }
    goToStep(currentStep + 1);
  }

  function previous() {
    goToStep(currentStep - 1);
  }

  function play() {
    if (timer) {
      return;
    }
    playPause.textContent = "暂停";
    playPause.setAttribute("aria-label", "暂停");
    timer = window.setInterval(next, 2600);
  }

  function pause() {
    if (!timer) {
      return;
    }
    window.clearInterval(timer);
    timer = null;
    playPause.textContent = "播放";
    playPause.setAttribute("aria-label", "播放");
  }

  playPause.addEventListener("click", () => {
    if (timer) {
      pause();
    } else {
      play();
    }
  });

  prevStep.addEventListener("click", () => {
    pause();
    previous();
  });

  nextStep.addEventListener("click", () => {
    pause();
    next();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "ArrowLeft") {
      pause();
      previous();
    }
    if (event.key === "ArrowRight") {
      pause();
      next();
    }
    if (event.key === " ") {
      event.preventDefault();
      timer ? pause() : play();
    }
  });

  renderMarkers();
  render();

  window.slide8Animation = {
    goToStep,
    next,
    previous,
    play,
    pause,
    getCurrentStep: () => currentStep
  };
})();
```

- [ ] **Step 2: Verify smoke-test hook**

Run:

```powershell
Select-String -Path 'docs\week01_slide8_c_to_cpu_animation\app.js' -Pattern 'window.slide8Animation'
```

Expected: output includes `window.slide8Animation`.

- [ ] **Step 3: Commit**

```bash
git add docs/week01_slide8_c_to_cpu_animation/app.js
git commit -m "feat: add slide8 animation controls"
```

---

### Task 4: Browser Verification And Polish

**Files:**
- Modify: `docs/week01_slide8_c_to_cpu_animation/index.html`
- Modify: `docs/week01_slide8_c_to_cpu_animation/styles.css`
- Modify: `docs/week01_slide8_c_to_cpu_animation/app.js`

**Interfaces:**
- Consumes: complete static page from Tasks 1-3.
- Produces: verified offline teaching page with readable layout and functional controls.

- [ ] **Step 1: Check required files**

Run:

```powershell
Get-ChildItem 'docs\week01_slide8_c_to_cpu_animation' | Select-Object Name,Length
```

Expected: output includes `index.html`, `styles.css`, and `app.js`.

- [ ] **Step 2: Check for external dependencies**

Run:

```powershell
Select-String -Path 'docs\week01_slide8_c_to_cpu_animation\*.html','docs\week01_slide8_c_to_cpu_animation\*.css','docs\week01_slide8_c_to_cpu_animation\*.js' -Pattern 'https?://|cdn|npm|unpkg'
```

Expected: no matches.

- [ ] **Step 3: Check core teaching copy**

Run:

```powershell
Select-String -Path 'docs\week01_slide8_c_to_cpu_animation\*.*' -Pattern 'CPU 真的认识变量名|变量名 -> 参数位置 -> 寄存器|add.w r4, r4, r5|return 8'
```

Expected: output includes all four teaching strings.

- [ ] **Step 4: Open offline page**

Open `docs/week01_slide8_c_to_cpu_animation/index.html` in a browser.

Expected:

- The page loads without a server.
- The layout shows C code, conversion process, and CPU execution.
- The bottom controls are visible.
- Clicking next reaches the final `return 8` summary.
- Clicking previous moves backward.
- Clicking play advances through the steps and then stops at the final step.

- [ ] **Step 5: Commit verification fixes**

If polish changes were needed, commit them:

```bash
git add docs/week01_slide8_c_to_cpu_animation
git commit -m "fix: polish slide8 animation verification"
```

If no polish changes were needed, do not create an empty commit.


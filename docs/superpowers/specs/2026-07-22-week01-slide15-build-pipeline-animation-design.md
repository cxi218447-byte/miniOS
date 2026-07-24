# Week 01 Slide 15 Build Pipeline Animation Design

## Purpose

Create an offline classroom animation for week 01 slide 15, "编译流程，用到本实验里".

The slide answers one concrete question:

```text
make 到底把 .c/.S 文件变成了什么，QEMU 又运行了什么？
```

Students should leave the page understanding that source files are not run directly. The build process turns visible project files into object files, links them with a linker script into `build/minios.elf`, and QEMU loads that ELF to start execution at `_start`.

## Teaching Answer

The answer shown by the animation is:

```text
.c/.S：源代码，给人和编译器看的 C/汇编文本
编译：把源代码翻译成目标文件 .o，并处理 include
链接：把多个 .o 合成 minios.elf，确定入口地址和内存布局
QEMU：加载 ELF，从 _start 开始模拟 LoongArch CPU 执行
```

The final summary must include:

```text
kernel/main.c + boot/start.S
  -> build/kernel/main.o + build/boot/start.o
  -> build/minios.elf
  -> QEMU
  -> Hello miniOS on LoongArch64
```

## Visual Concept

Use a single continuous "实验桌流水线" instead of separate abstract cards.

The screen shows real objects arranged left to right:

1. A project folder holding `kernel/main.c` and `boot/start.S`.
2. A compiler tool labeled `loongarch64-linux-gnu-gcc`.
3. A `build/` folder containing `main.o` and `start.o`.
4. A linker station that also receives `kernel/linker.ld`.
5. A final file labeled `build/minios.elf`.
6. A QEMU window labeled `qemu-system-loongarch64`, ending with terminal output.

Each object should look like a tangible classroom artifact: folder, document sheet, tool/machine, file, or terminal window. Text labels should use real repository paths and command/tool names, so students can map the animation back to the miniOS directory.

## Interaction Model

Use a step player:

- Play/pause for classroom playback.
- Previous/next for teacher-paced explanation.
- Step markers for student self-study.
- Keyboard support: left arrow, right arrow, and space.

The page must work offline by directly opening `index.html`. No package manager, backend, CDN, or network asset is allowed.

## Storyboard

### Step 1: Ask The Build Question

Show the project folder, source files, and question:

```text
make 到底做了什么？
```

Emphasize that `main.c` and `start.S` are source files, not directly runnable programs.

### Step 2: Pick Up Source Files

Highlight:

```text
kernel/main.c
boot/start.S
include/*.h
```

Show that C files, assembly files, and headers are inputs to the toolchain.

### Step 3: Compile To Object Files

Animate source files moving through:

```text
loongarch64-linux-gnu-gcc
```

Produce:

```text
build/kernel/main.o
build/boot/start.o
```

Explain that `.o` files already contain machine-code fragments, but are not yet the final kernel image.

### Step 4: Link With The Linker Script

Bring in:

```text
kernel/linker.ld
```

Show three linker responsibilities:

```text
ENTRY(_start)
起始地址
段布局：.text .rodata .data .bss
```

### Step 5: Produce The ELF

Show:

```text
build/minios.elf
```

Explain that this is the file QEMU loads with `-kernel`.

### Step 6: QEMU Loads And Starts

Show the QEMU terminal window:

```text
qemu-system-loongarch64 -M virt -nographic -kernel build/minios.elf
```

Animate the execution path:

```text
_start -> kernel_main -> printk -> UART
```

### Step 7: Final Answer

Show terminal output:

```text
Hello miniOS on LoongArch64
```

Then show the one-line answer:

```text
源文件不是直接运行的；make 组织编译和链接，QEMU 加载最终 ELF。
```

## Page Layout

Use a one-screen teaching surface:

- Header: slide title and current question.
- Main area: horizontal build pipeline with real objects.
- Detail strip: current command, generated file, or teacher explanation.
- Bottom controls: play/pause, previous, next, step markers.

Avoid a three-column abstract panel layout. The primary visual should be one continuous pipeline so students can follow movement from source file to QEMU output.

## Visual Style

- Course-oriented, clear, and readable for projection.
- Use restrained color groups:
  - Source files: green.
  - Tools: blue.
  - Build outputs: amber.
  - Runtime/QEMU: teal.
- Use simple CSS-built icons or shapes for folders, documents, tools, ELF file, and terminal window.
- Keep cards at 8px radius or less.
- Avoid decorative gradients, stock imagery, or unrelated visual effects.

## Technical Shape

Preferred file structure:

```text
docs/week01_slide15_build_pipeline_animation/
  index.html
  styles.css
  app.js
```

Use plain HTML, CSS, and JavaScript:

- `index.html` contains semantic markup for the pipeline objects and controls.
- `styles.css` contains layout, visual states, and responsive behavior.
- `app.js` contains the step definitions and player state machine.

Expose a smoke-test API:

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

## Verification

Verify:

- Required files exist and are non-empty.
- No external dependencies appear in HTML/CSS/JS.
- The text includes `kernel/main.c`, `boot/start.S`, `loongarch64-linux-gnu-gcc`, `kernel/linker.ld`, `build/minios.elf`, `qemu-system-loongarch64`, and `Hello miniOS on LoongArch64`.
- `node --check app.js` passes.
- Browser smoke test can open the local page and jump to the final step through `window.slide15Animation.goToStep(6)`.
- A headless screenshot is non-empty and shows the pipeline, controls, and QEMU output area.

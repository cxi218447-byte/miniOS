# Week 01 Slide 8 C-to-CPU Animation Design

## Purpose

Create a single-page web animation for week 01 slide 8 of `week01_qemu_hello_course_v2.pptx`.

The animation explains this classroom prompt:

```c
int add(int a, int b) { return a + b; }
```

Students should understand that `a` and `b` are source-level names for humans, while the CPU executes instructions over registers, values, and return conventions.

## Teaching Context

The page supports both classroom projection and student self-study.

- In class, the teacher can auto-play the explanation or step through it.
- After class, students can replay each step manually and inspect the mapping from C code to machine-level execution.
- The animation should align with the slide's two questions:
  - Does the CPU really understand variable names `a` and `b`?
  - What lower-level actions are needed for `return a + b`?

## Recommended Approach

Use a standalone HTML/CSS/JavaScript page with no backend and no build requirement.

This keeps the artifact easy to distribute with course materials and easy to open from a local browser. The page should work offline.

## Interaction Model

The animation is a step player:

- Play/pause button for automatic classroom playback.
- Previous/next buttons for teacher-paced explanation.
- Clickable step markers for student review.
- Each step updates the code highlight, mapping labels, register board, instruction line, and summary sentence.

## Animation Storyboard

### Step 1: Show The C Function

Display the C function prominently:

```c
int add(int a, int b) {
    return a + b;
}
```

Focus question:

```text
CPU 真的认识变量名 a 和 b 吗？
```

### Step 2: Highlight Human Names

Highlight `a` and `b` in the C code.

Show the message:

```text
变量名帮助程序员理解代码，但 CPU 不直接执行变量名。
```

### Step 3: Convert Names To Argument Slots

Animate the labels:

```text
a -> 参数1
b -> 参数2
```

The goal is to separate source-code naming from calling-convention position.

### Step 4: Place Arguments In Registers

Use a simple LoongArch teaching convention:

```text
参数1 -> r4
参数2 -> r5
返回值 -> r4
```

For the example call:

```c
add(3, 5)
```

show:

```text
r4 = 3
r5 = 5
```

### Step 5: Execute Addition

Show a simplified instruction:

```asm
add.w r4, r4, r5
```

Animate:

```text
r4(3) + r5(5) -> r4(8)
```

### Step 6: Return The Result

Show:

```text
return 8
```

Then connect it back to the C statement:

```c
return a + b;
```

### Step 7: Summarize The Lesson

Final conclusion:

```text
C 语言变量名是给人看的。
CPU 执行的是寄存器、指令和数据流。
汇编帮助我们看见 C 语言和机器执行之间的转换过程。
```

## Page Layout

Use a three-zone teaching layout:

- Left: C code panel.
- Center: transformation lane showing `变量名 -> 参数位置 -> 寄存器`.
- Right: CPU/register panel showing `r4`, `r5`, current instruction, and result.

Use a fixed bottom control bar for playback controls and step progress.

## Visual Style

The visual tone should match a systems course:

- Clear, high-contrast teaching interface.
- Avoid decorative landing-page styling.
- Use restrained colors to distinguish source code, mappings, registers, and CPU execution.
- Ensure text is readable on classroom projection.

## Technical Shape

Preferred file structure:

```text
docs/week01_slide8_c_to_cpu_animation/
  index.html
  styles.css
  app.js
```

The implementation should use plain browser APIs:

- CSS transitions for highlights and motion.
- JavaScript state machine for step control.
- No external network dependencies.

## Verification

Verify manually in a browser or with a local static server:

- The page opens offline.
- Play, pause, previous, next, and step markers work.
- Each step clearly changes visible state.
- Text fits at common classroom display sizes and on a laptop viewport.
- The final summary matches the lesson objective from slide 8.

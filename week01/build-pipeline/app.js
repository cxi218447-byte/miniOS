(function () {
  const steps = [
    {
      sourcePath: "kernel/main.c",
      sourceRole: "C 源码",
      question: "先从 Hello 的 C 代码看起：CPU 能直接运行这两行吗？",
      code: `const char *msg = "Hello miniOS on LoongArch64\\n";
printk(msg);`,
      input: "kernel/main.c",
      output: "build/kernel/main.o",
      command: "$(BUILD_DIR)/%.o: %.c\n\t$(CC) $(CFLAGS) -Iinclude -c $< -o $@",
      answer: "C 文件里有学生能看懂的 `printk(msg)`，但 CPU 不直接执行 C 文本；它要先变成 LoongArch 机器指令片段。",
      lineExplain: "const char *msg = ...：定义一个只读字符串指针，字符串内容就是终端要看到的 Hello。\nprintk(msg)：把 msg 交给 miniOS 自己实现的输出函数；裸机环境不能直接调用标准库 printf。",
      transition: "下一步要看：CPU 上电后并不会先找这两行 C 代码，它会从启动汇编 `_start` 进入内核。",
      terminal: "等待 build/minios.elf"
    },
    {
      sourcePath: "boot/start.S",
      sourceRole: "启动汇编",
      question: "裸机程序第一条路径在哪里？不是 kernel_main，而是 _start。",
      code: `_start:
    la.global   $sp, boot_stack_top
    bl          clear_bss
    bl          kernel_main`,
      input: "boot/start.S",
      output: "build/boot/start.o",
      command: "$(BUILD_DIR)/%.o: %.S\n\t$(CC) $(ASFLAGS) -Iinclude -c $< -o $@",
      answer: "`start.S` 解决 C 代码运行前的问题：设置栈、清零 .bss，然后通过 `bl kernel_main` 进入 C 函数。",
      lineExplain: "_start: 这是链接脚本指定的入口符号，也是裸机内核的第一段执行路径。\nla.global   $sp, boot_stack_top：把栈顶地址装入 $sp，C 函数调用需要先有可用栈。\nbl          clear_bss：调用清零 .bss 的汇编例程，保证未初始化全局变量从 0 开始。\nbl          kernel_main：跳转到 C 语言内核入口，返回地址写入 $ra。",
      transition: "下一步要看：这些 `.c` 和 `.S` 文本文件都要先经过 Makefile 规则，分别生成目标文件 `.o`。",
      terminal: "_start will call kernel_main"
    },
    {
      sourcePath: "Makefile",
      sourceRole: "C 编译规则",
      question: "Makefile 怎样把 kernel/main.c 变成 main.o？",
      code: `$(BUILD_DIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -Iinclude -c $< -o $@`,
      input: "kernel/main.c",
      output: "build/kernel/main.o",
      command: "loongarch64-linux-gnu-gcc -Iinclude -c kernel/main.c -o build/kernel/main.o",
      answer: "`-c` 的意思是只编译，不链接。这里生成的是 `.o`，还不是能被 QEMU 加载的完整内核。",
      lineExplain: "$(BUILD_DIR)/%.o: %.c：声明规则，任何 `.c` 都可以生成 build 目录下对应的 `.o`。\nmkdir -p $(dir $@)：先创建输出目录，避免 build/kernel 不存在。\n$(CC) $(CFLAGS) -Iinclude -c $< -o $@：用交叉 gcc 编译输入文件；`-Iinclude` 找头文件，`-c` 只生成目标文件。",
      transition: "下一步要看：C 文件会变成 `main.o`，启动汇编 `boot/start.S` 也要按类似方式变成 `start.o`。",
      terminal: "CC kernel/main.c -> build/kernel/main.o"
    },
    {
      sourcePath: "Makefile",
      sourceRole: "汇编编译规则",
      question: "Makefile 怎样把 boot/start.S 变成 start.o？",
      code: `$(BUILD_DIR)/%.o: %.S
	mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -Iinclude -c $< -o $@`,
      input: "boot/start.S",
      output: "build/boot/start.o",
      command: "loongarch64-linux-gnu-gcc -Iinclude -c boot/start.S -o build/boot/start.o",
      answer: "`.S` 文件也会进入交叉工具链，变成目标文件。这样 `_start` 这段启动机器指令才能进入最终 ELF。",
      lineExplain: "$(BUILD_DIR)/%.o: %.S：声明汇编源文件的生成规则，输入是大写 `.S` 文件。\nmkdir -p $(dir $@)：创建 build/boot 这类输出目录。\n$(CC) $(ASFLAGS) -Iinclude -c $< -o $@：仍然用交叉 gcc 驱动汇编流程，把 `_start` 等汇编代码编成 `start.o`。",
      transition: "下一步要看：`main.o` 和 `start.o` 只是零件，必须由链接脚本安排入口和内存布局。",
      terminal: "AS boot/start.S -> build/boot/start.o"
    },
    {
      sourcePath: "kernel/linker.ld",
      sourceRole: "链接脚本",
      question: "链接脚本为什么必须参与？它决定 CPU 从哪里开始。",
      code: `ENTRY(_start)

.text : ALIGN(4K) {
    KEEP(*(.text.boot))
    *(.text .text.*)
}`,
      input: "main.o + start.o + linker.ld",
      output: "build/minios.elf",
      command: "$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)",
      answer: "`ENTRY(_start)` 指定入口；`KEEP(*(.text.boot))` 保证启动汇编放进镜像并保留在关键位置。",
      lineExplain: "ENTRY(_start)：告诉链接器最终 ELF 的入口符号是 `_start`，不是 `main` 或 `kernel_main`。\n.text : ALIGN(4K)：把代码段按 4KB 边界对齐，便于形成稳定的内核布局。\nKEEP(*(.text.boot))：保留启动代码所在段，避免关键入口被链接优化丢掉。\n*(.text .text.*)：收集其他普通代码段，包括 C 编译出来的函数机器码。",
      transition: "下一步要看：链接器按 `kernel/linker.ld` 把多个 `.o` 合成 QEMU 真正加载的 `build/minios.elf`。",
      terminal: "ENTRY(_start)\nKEEP(*(.text.boot))"
    },
    {
      sourcePath: "Makefile",
      sourceRole: "链接与运行规则",
      question: "QEMU 真正加载的是哪个文件？",
      code: `$(TARGET): $(OBJS) kernel/linker.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)

run: $(TARGET)
	$(QEMU) $(QEMU_ARGS)`,
      input: "build/minios.elf",
      output: "qemu-system-loongarch64",
      command: "qemu-system-loongarch64 -M virt -nographic -kernel build/minios.elf",
      answer: "`make` 先合成 `build/minios.elf`；`make run` 再让 QEMU 用 `-kernel` 加载这个 ELF。",
      lineExplain: "$(TARGET): $(OBJS) kernel/linker.ld：说明 ELF 依赖所有目标文件和链接脚本。\n$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)：执行链接，输出 `build/minios.elf`。\nrun: $(TARGET)：运行前先确保 ELF 已经生成。\n$(QEMU) $(QEMU_ARGS)：启动 LoongArch QEMU，并通过 `-kernel build/minios.elf` 加载内核。",
      transition: "下一步要看：QEMU 加载 ELF 后，执行路径会从 `_start` 接到 `kernel_main`，再到 `printk` 和 UART。",
      terminal: "ELF ready: build/minios.elf\nQEMU loads ELF, not .c"
    },
    {
      sourcePath: "执行路径",
      sourceRole: "最终答案",
      question: "所以第 15 页的答案是什么？",
      code: `kernel/main.c + boot/start.S
    -> build/kernel/main.o + build/boot/start.o
    -> build/minios.elf
    -> QEMU
    -> Hello miniOS on LoongArch64`,
      input: "source files",
      output: "Hello miniOS",
      command: "_start -> kernel_main -> printk -> UART",
      answer: "源文件不是直接运行的；Makefile 组织编译和链接，QEMU 加载最终 ELF，然后从 `_start` 开始执行到 Hello 输出。",
      lineExplain: "kernel/main.c + boot/start.S：人写的 C 和汇编源码，是构建输入。\nbuild/kernel/main.o + build/boot/start.o：交叉编译后的目标文件，已经包含机器代码片段。\nbuild/minios.elf：链接后的完整内核镜像，包含入口、地址和段布局。\nQEMU：加载 ELF 并模拟 LoongArch CPU 执行。\nHello miniOS on LoongArch64：`printk` 通过 UART 最终显示出的结果。",
      transition: "下一步回到课堂问题：看到 Hello 后，要能反向说出它来自源码、编译、链接、加载和启动入口这条完整链路。",
      terminal: "_start -> kernel_main -> printk -> UART\nHello miniOS on LoongArch64"
    }
  ];

  const app = document.getElementById("app");
  const sourcePath = document.getElementById("sourcePath");
  const sourceRole = document.getElementById("sourceRole");
  const questionText = document.getElementById("questionText");
  const codeText = document.getElementById("codeText");
  const inputArtifact = document.getElementById("inputArtifact");
  const outputArtifact = document.getElementById("outputArtifact");
  const commandText = document.getElementById("commandText");
  const answerText = document.getElementById("answerText");
  const lineExplainText = document.getElementById("lineExplainText");
  const transitionText = document.getElementById("transitionText");
  const terminalOutput = document.getElementById("terminalOutput");
  const playPause = document.getElementById("playPause");
  const prevStep = document.getElementById("prevStep");
  const nextStep = document.getElementById("nextStep");
  const stepMarkers = document.getElementById("stepMarkers");

  let currentStep = 0;
  let timer = null;

  function renderMarkers() {
    stepMarkers.innerHTML = "";
    steps.forEach((step, index) => {
      const marker = document.createElement("button");
      marker.className = "step-marker";
      marker.type = "button";
      marker.setAttribute("aria-label", `第 ${index + 1} 步：${step.question}`);
      marker.addEventListener("click", () => {
        pause();
        goToStep(index);
      });
      stepMarkers.appendChild(marker);
    });
  }

  function render() {
    const step = steps[currentStep];
    app.dataset.step = String(currentStep);
    sourcePath.textContent = step.sourcePath;
    sourceRole.textContent = step.sourceRole;
    questionText.textContent = step.question;
    codeText.textContent = step.code;
    inputArtifact.textContent = step.input;
    outputArtifact.textContent = step.output;
    commandText.textContent = step.command;
    answerText.textContent = step.answer;
    lineExplainText.textContent = step.lineExplain;
    transitionText.textContent = step.transition;
    terminalOutput.textContent = step.terminal;
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
    timer = window.setInterval(next, 3000);
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

  window.slide15Animation = {
    goToStep,
    next,
    previous,
    play,
    pause,
    getCurrentStep: () => currentStep
  };
})();

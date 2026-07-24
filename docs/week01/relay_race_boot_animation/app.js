(function () {
  const steps = [
    {
      node: "judge",
      headline: "QEMU 裁判员鸣枪，比赛开始",
      detail: "裁判员把 build/minios.elf 放上起跑线——加载进虚拟内存，按 ELF 头找到入口地址，然后鸣枪：CPU 从入口地址取出第一条指令，此时还没有任何 C 环境。",
      code: "qemu-system-loongarch64 -M virt -nographic -kernel build/minios.elf",
      terminal: "等待比赛开始...",
      typewriter: false
    },
    {
      node: "start",
      headline: "_start 第一棒：先系鞋带，再交棒",
      detail: "_start 是第一棒选手，上场第一件事是把 $sp 指向预留的栈空间（系好鞋带）——没有这一步，C 函数完全不能用。准备好之后，用 bl kernel_main 把接力棒交给下一棒。",
      code: "_start:\n    la.global   $sp, boot_stack_top\n    bl          kernel_main",
      terminal: "_start: $sp <- boot_stack_top\n_start: bl kernel_main",
      typewriter: false
    },
    {
      node: "kernelmain",
      headline: "kernel_main 主力选手：跑出真正的比赛内容",
      detail: "接到棒之后，kernel_main 才是我们熟悉的 C 语言世界。它调用 printk，把 Hello 字符串交出去——这是整场比赛真正要跑的那一段。",
      code: "void kernel_main(void)\n{\n    printk(\"Hello miniOS on LoongArch64\\n\");\n}",
      terminal: "kernel_main() running...\ncall printk(...)",
      typewriter: false
    },
    {
      node: "uart",
      headline: "printk 喊成绩给场边记录员",
      detail: "printk 逐字符调用 uart_putc，uart_putc 直接向 UART0_BASE 这个内存地址写字节——这不是普通内存，是外设寄存器，相当于选手对着场边喊出每一个字。",
      code: "*(volatile unsigned char *)UART0_BASE = ch;",
      terminal: "uart_putc('H') -> UART0_BASE\nuart_putc('e') -> UART0_BASE\n...",
      typewriter: false
    },
    {
      node: "terminal",
      headline: "QEMU 终端记分牌：把成绩显示给所有观众",
      detail: "QEMU 把这一连串写 UART 的操作翻译成终端输出——记分牌亮起，所有观众（也就是我们）终于看到成绩。",
      code: "QEMU 串口 -> 宿主机终端 stdio",
      terminal: "",
      typewriter: true,
      typewriterText: "Hello miniOS on LoongArch64"
    },
    {
      node: "halt",
      headline: "halt 循环：赛后原地休息",
      detail: "kernel_main 结束后代码进入 halt 死循环。裸机没有『返回到操作系统』这回事，也没有下一场比赛可跑，选手只能原地待命。",
      code: "halt:\n    idle        0\n    b           halt",
      terminal: "Hello miniOS on LoongArch64\n[halt] idle loop...",
      typewriter: false
    }
  ];

  const nodeOrder = ["judge", "start", "kernelmain", "uart", "terminal", "halt"];

  const app = document.getElementById("app");
  const headline = document.getElementById("headline");
  const detailText = document.getElementById("detailText");
  const codeText = document.getElementById("codeText");
  const terminalOutput = document.getElementById("terminalOutput");
  const trackPulse = document.getElementById("trackPulse");
  const trackNodes = document.getElementById("trackNodes");
  const nodeEls = Array.from(trackNodes.querySelectorAll(".node"));
  const playPause = document.getElementById("playPause");
  const prevStep = document.getElementById("prevStep");
  const nextStep = document.getElementById("nextStep");
  const stepMarkers = document.getElementById("stepMarkers");

  let currentStep = 0;
  let timer = null;
  let typeTimer = null;

  function renderMarkers() {
    stepMarkers.innerHTML = "";
    steps.forEach((step, index) => {
      const marker = document.createElement("button");
      marker.className = "step-marker";
      marker.type = "button";
      marker.setAttribute("aria-label", `第 ${index + 1} 步：${step.headline}`);
      marker.addEventListener("click", () => {
        pause();
        goToStep(index);
      });
      stepMarkers.appendChild(marker);
    });
  }

  function pulsePosition(index) {
    const pct = (index / (steps.length - 1)) * 100;
    return `calc(60px + (100% - 120px) * ${pct / 100})`;
  }

  function stopTypewriter() {
    if (typeTimer) {
      window.clearInterval(typeTimer);
      typeTimer = null;
    }
  }

  function runTypewriter(text) {
    stopTypewriter();
    let i = 0;
    terminalOutput.textContent = "";
    const cursor = document.createElement("span");
    cursor.className = "cursor";
    cursor.textContent = "▌";
    terminalOutput.appendChild(cursor);
    typeTimer = window.setInterval(() => {
      i += 1;
      terminalOutput.textContent = text.slice(0, i);
      terminalOutput.appendChild(cursor);
      if (i >= text.length) {
        stopTypewriter();
      }
    }, 60);
  }

  function render() {
    const step = steps[currentStep];
    app.dataset.step = String(currentStep);
    headline.textContent = step.headline;
    detailText.textContent = step.detail;
    codeText.textContent = step.code;

    nodeEls.forEach((el, index) => {
      el.classList.toggle("active", index === currentStep);
      el.classList.toggle("done", index < currentStep);
    });
    trackPulse.style.left = pulsePosition(currentStep);

    if (step.typewriter) {
      runTypewriter(step.typewriterText);
    } else {
      stopTypewriter();
      terminalOutput.innerHTML = "";
      terminalOutput.textContent = step.terminal;
      const cursor = document.createElement("span");
      cursor.className = "cursor";
      cursor.textContent = "▌";
      terminalOutput.appendChild(cursor);
    }

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
    playPause.textContent = "⏸ 暂停";
    playPause.setAttribute("aria-label", "暂停");
    timer = window.setInterval(next, 2500);
  }

  function pause() {
    if (!timer) {
      return;
    }
    window.clearInterval(timer);
    timer = null;
    playPause.textContent = "▶ 播放";
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

  window.relayRaceAnimation = {
    goToStep,
    next,
    previous,
    play,
    pause,
    getCurrentStep: () => currentStep,
    nodeOrder
  };
})();

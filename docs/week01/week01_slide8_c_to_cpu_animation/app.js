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
      marker.setAttribute("aria-label", `第 ${index + 1} 步：${step.question}`);
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

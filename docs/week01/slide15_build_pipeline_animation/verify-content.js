const fs = require("fs");
const path = require("path");
const vm = require("vm");

const appPath = path.join(__dirname, "app.js");
const source = fs.readFileSync(appPath, "utf8");

const textNodes = new Map();

function makeElement(id) {
  let textContent = "";
  return {
    id,
    children: [],
    className: "",
    dataset: {},
    disabled: false,
    type: "",
    set textContent(value) {
      textContent = String(value);
      textNodes.set(id, textContent);
    },
    get textContent() {
      return textContent;
    },
    setAttribute() {},
    addEventListener() {},
    appendChild(child) {
      this.children.push(child);
    },
    classList: {
      toggle() {},
    },
  };
}

const elements = new Map([
  "app",
  "sourcePath",
  "sourceRole",
  "questionText",
  "codeText",
  "inputArtifact",
  "outputArtifact",
  "commandText",
  "answerText",
  "lineExplainText",
  "transitionText",
  "terminalOutput",
  "playPause",
  "prevStep",
  "nextStep",
  "stepMarkers",
].map((id) => [id, makeElement(id)]));

const context = {
  console,
  window: {
    setInterval() {
      return 1;
    },
    clearInterval() {},
  },
  document: {
    getElementById(id) {
      return elements.get(id) || makeElement(id);
    },
    createElement() {
      return makeElement("dynamic");
    },
    addEventListener() {},
  },
};

vm.createContext(context);
vm.runInContext(source, context, { filename: appPath });

const api = context.window.slide15Animation;
if (!api) {
  throw new Error("window.slide15Animation is not exposed");
}

const requiredLineFragments = [
  "const char *msg",
  "printk(msg)",
  "la.global   $sp",
  "bl          clear_bss",
  "bl          kernel_main",
  "$(BUILD_DIR)/%.o: %.c",
  "$(CC) $(CFLAGS)",
  "ENTRY(_start)",
  "KEEP(*(.text.boot))",
  "$(QEMU) $(QEMU_ARGS)",
];

for (let index = 0; index <= 6; index += 1) {
  api.goToStep(index);
  const lineExplain = textNodes.get("lineExplainText") || "";
  const transition = textNodes.get("transitionText") || "";

  if (lineExplain.length < 40) {
    throw new Error(`step ${index} lacks line-by-line explanation`);
  }
  if (!transition.includes("下一步")) {
    throw new Error(`step ${index} lacks a coherent next-step transition`);
  }
}

for (const fragment of requiredLineFragments) {
  const found = Array.from({ length: 7 }, (_, index) => {
    api.goToStep(index);
    return (textNodes.get("lineExplainText") || "").includes(fragment);
  }).some(Boolean);

  if (!found) {
    throw new Error(`missing line explanation for: ${fragment}`);
  }
}

api.goToStep(6);
if (!(textNodes.get("terminalOutput") || "").includes("Hello miniOS on LoongArch64")) {
  throw new Error("final terminal output is missing Hello miniOS");
}

console.log("slide15 content verification passed");

import { later } from "@ember/runloop";
import { getURLWithCDN } from "discourse/lib/get-url";
import loadKaTeX from "discourse/lib/load-katex";
import loadMathJax from "discourse/lib/load-mathjax";
import { getMathJaxBasePath } from "discourse/plugins/discourse-math/lib/math-bundle-paths";

const CSS_CLASSES = {
  HIDDEN: "math-hidden",
  APPLIED_MATHJAX: "math-applied-mathjax",
  APPLIED_KATEX: "math-applied-katex",
};

const PREVIEW_RENDER_DELAY = 200;

class MathJaxState {
  #initialized = false;
  #configHash = null;

  reset() {
    this.#initialized = false;
    this.#configHash = null;
  }

  isInitializedWith(configHash) {
    return this.#initialized && this.#configHash === configHash;
  }

  markInitialized(configHash) {
    this.#initialized = true;
    this.#configHash = configHash;
  }
}

const mathJaxState = new MathJaxState();

export function resetMathJaxState() {
  mathJaxState.reset();
}

function getConfigHash(opts) {
  return JSON.stringify({
    output: opts.mathjax_output,
    a11y: opts.enable_accessibility,
    zoom: opts.zoom_on_click,
    ascii: opts.enable_asciimath,
  });
}

export function buildDiscourseMathOptions(siteSettings) {
  return {
    enabled: siteSettings.discourse_math_enabled,
    provider: siteSettings.discourse_math_provider,
    enable_menu: siteSettings.discourse_math_enable_menu,
    enable_asciimath: siteSettings.discourse_math_enable_asciimath,
    enable_accessibility: siteSettings.discourse_math_enable_accessibility,
    mathjax_output: siteSettings.discourse_math_mathjax_output,
    zoom_on_click: siteSettings.discourse_math_zoom_on_click,
  };
}

function buildMathJaxConfig(opts) {
  const mathJaxBasePath = getMathJaxBasePath();
  const MathJaxInitConfig = {
    startup: {
      typeset: false,
      ready() {
        return window.MathJax?.startup?.defaultReady?.();
      },
    },
    chtml: {},
    svg: {},
    loader: {
      load: ["ui/safe"],
      paths: { mathjax: getURLWithCDN(mathJaxBasePath) },
    },
    options: {
      menuOptions: { settings: {} },
    },
    tex: {
      inlineMath: [["\\(", "\\)"]],
      displayMath: [["\\[", "\\]"]],
    },
    asciimath: {
      delimiters: [["%", "%"]],
    },
  };
  if (opts.mathjax_output === "html") {
    MathJaxInitConfig.chtml.fontURL = getURLWithCDN(
      `${mathJaxBasePath}/woff-v2`
    );
  } else if (opts.mathjax_output === "svg") {
    MathJaxInitConfig.svg.fontCache = "global";
  }
  if (opts.enable_menu) {
    MathJaxInitConfig.options.enableMenu = true;
  } else {
    MathJaxInitConfig.options.enableMenu = false;
  }
  if (
    opts.enable_accessibility === true ||
    opts.enable_accessibility === "true"
  ) {
    MathJaxInitConfig.options.menuOptions.settings = { enrich: true };
  } else {
    MathJaxInitConfig.options.menuOptions.settings = { enrich: false };
  }
  if (opts.zoom_on_click) {
    MathJaxInitConfig.options.menuOptions.settings.zoom = "Click";
    MathJaxInitConfig.options.menuOptions.settings.zscale = "175%";
  }
  if (opts.enable_asciimath) {
    MathJaxInitConfig.loader.load.push("input/asciimath");
  }
  return MathJaxInitConfig;
}

function initMathJax(opts) {
  const configHash = getConfigHash(opts);

  if (mathJaxState.isInitializedWith(configHash)) {
    return;
  }

  window.MathJax = buildMathJaxConfig(opts);
  mathJaxState.markInitialized(configHash);
}

async function ensureMathJax(opts) {
  initMathJax(opts);

  return await loadMathJax({
    // enableAsciimath: opts.enable_asciimath,
    // enableAccessibility: opts.enable_accessibility,
    output: opts.mathjax_output,
  });
}

function createHiddenWrapper(tag, className, content) {
  const wrapper = document.createElement(tag);
  wrapper.className = `${className} ${CSS_CLASSES.HIDDEN}`;
  wrapper.setAttribute("hidden", "");
  wrapper.textContent = content;
  return wrapper;
}

function buildMathJaxWrapper(elem) {
  if (elem.classList.contains("math")) {
    const tag = elem.tagName === "DIV" ? "div" : "span";
    const displayClass = tag === "div" ? "block-math" : "inline-math";
    const delimiter = tag === "div" ? ["\\[", "\\]"] : ["\\(", "\\)"];
    const content = `${delimiter[0]}${elem.textContent}${delimiter[1]}`;

    const wrapper = createHiddenWrapper(
      tag,
      `math-container ${displayClass} mathjax-math`,
      content
    );
    elem.after(wrapper);
    return wrapper;
  }

  if (elem.classList.contains("asciimath")) {
    const wrapper = createHiddenWrapper(
      "span",
      "math-container inline-math ascii-math mathjax-math",
      `%${elem.textContent}%`
    );
    elem.after(wrapper);
    return wrapper;
  }

  return null;
}

function resetMathJax(elem, opts) {
  const selector = opts.enable_asciimath ? ".math, .asciimath" : ".math";

  elem.querySelectorAll(selector).forEach((mathElem) => {
    mathElem.classList.remove(CSS_CLASSES.APPLIED_MATHJAX, CSS_CLASSES.HIDDEN);
    mathElem.removeAttribute("hidden");
  });

  elem
    .querySelectorAll(".math-container.mathjax-math")
    .forEach((wrapper) => wrapper.remove());
}

function collectMathWrappers(elem, opts) {
  const selector = opts.enable_asciimath ? ".math, .asciimath" : ".math";
  const mathElems = elem.querySelectorAll(selector);
  const wrappers = [];

  mathElems.forEach((mathElem) => {
    if (mathElem.classList.contains(CSS_CLASSES.APPLIED_MATHJAX)) {
      return;
    }

    mathElem.classList.add(CSS_CLASSES.APPLIED_MATHJAX);
    const wrapper = buildMathJaxWrapper(mathElem);

    if (wrapper) {
      wrappers.push({ original: mathElem, wrapper });
    }
  });

  return wrappers;
}

function filterActiveWrappers(wrappers) {
  return wrappers.filter(
    ({ original, wrapper }) =>
      wrapper?.isConnected && original?.parentElement?.offsetParent !== null
  );
}

function hideElement(elem) {
  if (elem?.isConnected) {
    elem.classList.add(CSS_CLASSES.HIDDEN);
    elem.setAttribute("hidden", "");
  }
}

function showElement(elem) {
  if (elem?.isConnected) {
    elem.classList.remove(CSS_CLASSES.HIDDEN);
    elem.removeAttribute("hidden");
  }
}

function stripMathJaxInlineStyles(wrapper) {
  wrapper.querySelectorAll("mjx-container").forEach((container) => {
    container.style.removeProperty("display");
  });
}

function showRenderedMath(active) {
  active.forEach(({ original, wrapper }) => {
    hideElement(original);
    if (wrapper?.isConnected) {
      stripMathJaxInlineStyles(wrapper);
      showElement(wrapper);
    }
  });
}

function revertFailedMathRendering(wrappers) {
  wrappers.forEach(({ original, wrapper }) => {
    if (original?.isConnected) {
      original.classList.remove(
        CSS_CLASSES.HIDDEN,
        CSS_CLASSES.APPLIED_MATHJAX
      );
      original.removeAttribute("hidden");
    }
    if (wrapper?.isConnected) {
      wrapper.remove();
    }
  });
}

async function typesetMathJax(wrappers, opts) {
  try {
    const MathJax = await ensureMathJax(opts);
    const active = filterActiveWrappers(wrappers);

    if (active.length === 0 || !MathJax?.typesetPromise) {
      return;
    }

    await MathJax.typesetPromise(active.map(({ wrapper }) => wrapper));
    showRenderedMath(active);
  } catch {
    revertFailedMathRendering(wrappers);
  }
}

export function renderMathJax(elem, opts, renderOptions = {}) {
  if (!elem) {
    return;
  }

  if (renderOptions.force) {
    resetMathJax(elem, opts);
  }

  const wrappers = collectMathWrappers(elem, opts);

  if (wrappers.length === 0) {
    return;
  }

  const isPreview = elem.classList.contains("d-editor-preview");
  const delay = isPreview ? PREVIEW_RENDER_DELAY : 0;

  later(() => typesetMathJax(wrappers, opts), delay);
}

async function ensureKaTeX() {
  await loadKaTeX({
    enableMhchem: true,
    enableCopyTex: true,
  });
}

function resetKatex(elem) {
  elem.querySelectorAll(".math").forEach((mathElem) => {
    mathElem.classList.remove(
      CSS_CLASSES.APPLIED_KATEX,
      "math-container",
      "inline-math",
      "block-math",
      "katex-math"
    );
  });
}

function decorateKatex(elem, katexOpts) {
  if (elem.classList.contains(CSS_CLASSES.APPLIED_KATEX)) {
    return;
  }

  if (!elem.classList.contains("math")) {
    return;
  }

  elem.classList.add(CSS_CLASSES.APPLIED_KATEX);

  const displayMode = elem.tagName === "DIV";
  const displayClass = displayMode ? "block-math" : "inline-math";
  const text = elem.textContent;
  elem.classList.add("math-container", displayClass, "katex-math");
  elem.textContent = "";

  try {
    window.katex.render(text, elem, { ...katexOpts, displayMode });
  } catch {
    elem.textContent = text;
    elem.classList.remove(
      CSS_CLASSES.APPLIED_KATEX,
      "math-container",
      displayClass,
      "katex-math"
    );
  }
}

export async function renderKatex(elem, renderOptions = {}) {
  if (!elem) {
    return;
  }

  const mathElems = elem.querySelectorAll(".math");
  if (mathElems.length === 0) {
    return;
  }

  if (renderOptions.force) {
    resetKatex(elem);
  }

  try {
    await ensureKaTeX();
  } catch {
    return;
  }

  const katexOpts = {
    trust: (context) => ["\\htmlId", "\\href"].includes(context.command),
    macros: {
      "\\eqref": "\\href{###1}{(\\text{#1})}",
      "\\ref": "\\href{###1}{\\text{#1}}",
      "\\label": "\\htmlId{#1}{}",
    },
    displayMode: false,
  };

  mathElems.forEach((mathElem) => decorateKatex(mathElem, katexOpts));
}

export function renderMathInElement(elem, opts, renderOptions = {}) {
  if (!elem || !opts?.enabled) {
    return;
  }

  if (opts.provider === "mathjax") {
    renderMathJax(elem, opts, renderOptions);
    return;
  }

  if (opts.provider === "katex") {
    renderKatex(elem, renderOptions);
  }
}

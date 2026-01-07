import { warn } from "@ember/debug";
import { cancel, later } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";
import { getURLWithCDN } from "discourse/lib/get-url";
import loadKaTeX from "discourse/lib/load-katex";
import loadMathJax from "discourse/lib/load-mathjax";
import { sanitize } from "discourse/lib/text";
import { getMathJaxBasePath } from "discourse/plugins/discourse-math/lib/math-bundle-paths";

const CSS_CLASSES = {
  HIDDEN: "math-hidden",
  APPLIED_MATHJAX: "math-applied-mathjax",
  APPLIED_KATEX: "math-applied-katex",
};

const PREVIEW_RENDER_DELAY = 200;
const ORIGINAL_TEXT_ATTR = "data-math-original";
const pendingMathJaxTypesets = new WeakMap();
const SAFE_HTML_ID_REGEX = /^[A-Za-z_][A-Za-z0-9_.:-]*$/;

function isSafeHtmlId(value) {
  return Boolean(value) && SAFE_HTML_ID_REGEX.test(value);
}

function sanitizeHref(url) {
  if (!url || /[<>"']/.test(url)) {
    return null;
  }

  try {
    const parsedUrl = new URL(url, window.location.origin);
    const isRelative = url.startsWith("/") || url.startsWith("#");
    const isAllowedProtocol = ["http:", "https:", "mailto:"].includes(
      parsedUrl.protocol
    );

    if (!isRelative && !isAllowedProtocol) {
      return null;
    }

    const sanitized = sanitize(url);
    if (
      !sanitized ||
      sanitized.trim() === "" ||
      sanitized.includes("&gt;") ||
      sanitized.includes("&lt;")
    ) {
      return null;
    }

    return sanitized;
  } catch {
    return null;
  }
}

function warnMathRender(message, error) {
  if (isTesting()) {
    return;
  }

  const suffix = error?.message ? ` (${error.message})` : "";
  warn(`discourse-math: ${message}${suffix}`, false, {
    id: "discourse-math.render",
  });
}

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
    menu: opts.enable_menu,
  });
}

export function buildDiscourseMathOptions(siteSettings) {
  const provider = siteSettings.discourse_math_provider;
  return {
    enabled: siteSettings.discourse_math_enabled,
    provider,
    enable_menu: siteSettings.discourse_math_enable_menu,
    enable_asciimath:
      siteSettings.discourse_math_enable_asciimath && provider === "mathjax",
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
  MathJaxInitConfig.options.menuOptions.settings = {
    enrich: Boolean(opts.enable_accessibility),
  };
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

  return await loadMathJax({ output: opts.mathjax_output });
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
      wrapper?.isConnected && isElementVisible(original)
  );
}

function isElementVisible(elem) {
  if (!elem?.isConnected) {
    return false;
  }

  if (elem.closest("[hidden]")) {
    return false;
  }

  const style = window.getComputedStyle(elem);
  return style.display !== "none" && style.visibility !== "hidden";
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
  } catch (error) {
    warnMathRender("MathJax rendering failed", error);
    revertFailedMathRendering(wrappers);
  }
}

function cancelPendingMathJaxTypeset(elem) {
  const pending = pendingMathJaxTypesets.get(elem);
  if (pending) {
    cancel(pending.timer);
    pendingMathJaxTypesets.delete(elem);
  }
}

function scheduleMathJaxTypeset(elem, wrappers, opts, delay) {
  const pending = pendingMathJaxTypesets.get(elem);

  if (pending) {
    cancel(pending.timer);

    const wrapperSet = new Set(pending.wrappers.map(({ wrapper }) => wrapper));
    wrappers.forEach((item) => {
      if (!wrapperSet.has(item.wrapper)) {
        pending.wrappers.push(item);
        wrapperSet.add(item.wrapper);
      }
    });
    pending.opts = opts;

    pending.timer = later(() => {
      pendingMathJaxTypesets.delete(elem);
      typesetMathJax(pending.wrappers, pending.opts);
    }, delay);
    return;
  }

  const entry = { wrappers: [...wrappers], opts, timer: null };
  entry.timer = later(() => {
    pendingMathJaxTypesets.delete(elem);
    typesetMathJax(entry.wrappers, entry.opts);
  }, delay);

  pendingMathJaxTypesets.set(elem, entry);
}

export function renderMathJax(elem, opts, renderOptions = {}) {
  if (!elem) {
    return;
  }

  if (renderOptions.force) {
    cancelPendingMathJaxTypeset(elem);
    resetMathJax(elem, opts);
  }

  const wrappers = collectMathWrappers(elem, opts);

  if (wrappers.length === 0) {
    return;
  }

  const isPreview = elem.classList.contains("d-editor-preview");
  const delay = isPreview ? PREVIEW_RENDER_DELAY : 0;

  scheduleMathJaxTypeset(elem, wrappers, opts, delay);
}

async function ensureKaTeX() {
  await loadKaTeX({
    enableMhchem: true,
    enableCopyTex: true,
  });
}

function resetKatex(elem) {
  elem.querySelectorAll(".math").forEach((mathElem) => {
    const originalText = mathElem.getAttribute(ORIGINAL_TEXT_ATTR);
    const hasKatexContent = !!mathElem.querySelector(".katex");
    if (originalText && hasKatexContent) {
      mathElem.textContent = originalText;
    }
    mathElem.removeAttribute(ORIGINAL_TEXT_ATTR);
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
  const hasKatexContent = !!elem.querySelector(".katex");
  const text = hasKatexContent
    ? elem.getAttribute(ORIGINAL_TEXT_ATTR)
    : elem.textContent;
  const annotationText = elem.querySelector(
    "annotation[encoding='application/x-tex']"
  )?.textContent;
  const rawText = text ?? annotationText ?? elem.textContent ?? "";
  elem.setAttribute(ORIGINAL_TEXT_ATTR, rawText);
  elem.classList.add("math-container", displayClass, "katex-math");
  elem.textContent = "";

  try {
    window.katex.render(rawText, elem, { ...katexOpts, displayMode });
  } catch (error) {
    warnMathRender("KaTeX rendering failed", error);
    elem.textContent = rawText;
    elem.removeAttribute(ORIGINAL_TEXT_ATTR);
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
  } catch (error) {
    warnMathRender("KaTeX failed to load", error);
    return;
  }

  const katexOpts = {
    trust: (context) => {
      if (context.command === "\\href") {
        return Boolean(sanitizeHref(context.url));
      }

      if (context.command === "\\htmlId") {
        const htmlId = context.url || context.text || context.id;
        return isSafeHtmlId(htmlId);
      }

      return false;
    },
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

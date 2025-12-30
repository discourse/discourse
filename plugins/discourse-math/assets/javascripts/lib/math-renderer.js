import { later } from "@ember/runloop";
import { getURLWithCDN } from "discourse/lib/get-url";
import loadKaTeX from "discourse/lib/load-katex";
import loadMathJax from "discourse/lib/load-mathjax";

let initializedMathJax = false;
let initializedMathJaxConfigHash = null;

export function resetMathJaxState() {
  initializedMathJax = false;
  initializedMathJaxConfigHash = null;
}

const CSS_CLASSES = {
  HIDDEN: "math-hidden",
  APPLIED_MATHJAX: "math-applied-mathjax",
  APPLIED_KATEX: "math-applied-katex",
};

function getConfigHash(opts) {
  return `${opts.mathjax_output}-${opts.enable_accessibility}-${opts.zoom_on_hover}-${opts.enable_asciimath}`;
}

export function buildDiscourseMathOptions(siteSettings) {
  return {
    enabled: siteSettings.discourse_math_enabled,
    provider: siteSettings.discourse_math_provider,
    enable_asciimath: siteSettings.discourse_math_enable_asciimath,
    enable_accessibility: siteSettings.discourse_math_enable_accessibility,
    mathjax_output: siteSettings.discourse_math_mathjax_output,
    zoom_on_hover: siteSettings.discourse_math_zoom_on_hover,
  };
}

function initMathJax(opts) {
  const configHash = getConfigHash(opts);

  // Skip if already initialized with the same configuration
  if (initializedMathJax && initializedMathJaxConfigHash === configHash) {
    return;
  }

  const output = opts.mathjax_output === "svg" ? "svg" : "html";
  const enableA11y =
    opts.enable_accessibility === true || opts.enable_accessibility === "true";

  const menuOptions = {};

  if (opts.zoom_on_hover) {
    menuOptions.settings = {
      zoom: "Hover",
      zscale: "200%",
    };
  }

  const mathJaxConfig = {
    tex: {
      inlineMath: [["\\(", "\\)"]],
      displayMath: [["\\[", "\\]"]],
    },
    asciimath: {
      delimiters: [["%", "%"]],
    },
    loader: {
      load: [],
      paths: {
        mathjax: getURLWithCDN("/assets/mathjax"),
      },
    },
    ...(output === "html"
      ? {
          chtml: {
            fontURL: getURLWithCDN("/assets/mathjax/woff-v2"),
          },
        }
      : {
          svg: {
            fontCache: "global",
          },
        }),
    options: {
      ...(enableA11y
        ? {
            enableAssistiveMml: true,
            enableExplorer: true,
            enableSpeech: true,
            enableBraille: true,
            enableEnrichment: true,
            sre: {
              path: getURLWithCDN("/assets/mathjax/sre"),
              maps: getURLWithCDN("/assets/mathjax/sre/mathmaps"),
            },
            a11y: {
              speech: true,
              braille: true,
            },
          }
        : {}),
      ...(Object.keys(menuOptions).length ? { menuOptions } : {}),
    },
    startup: {
      typeset: false,
      ready() {
        const MathJax = window.MathJax;
        return MathJax?.startup?.defaultReady?.();
      },
    },
  };

  window.MathJax = mathJaxConfig;
  initializedMathJax = true;
  initializedMathJaxConfigHash = configHash;
}

async function ensureMathJax(opts) {
  initMathJax(opts);

  try {
    const MathJax = await loadMathJax({
      enableAsciimath: opts.enable_asciimath,
      enableAccessibility: opts.enable_accessibility,
      output: opts.mathjax_output,
    });
    return MathJax;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("Failed to load MathJax:", error);
    throw error;
  }
}

function buildMathJaxWrapper(elem) {
  let tag;
  let classList;
  let content;

  if (elem.classList.contains("math")) {
    tag = elem.tagName === "DIV" ? "div" : "span";
    const displayClass = tag === "div" ? "block-math" : "inline-math";
    classList = `math-container ${displayClass} mathjax-math`;
    const delimiter = tag === "div" ? ["\\[", "\\]"] : ["\\(", "\\)"];
    content = `${delimiter[0]}${elem.textContent}${delimiter[1]}`;
  } else if (elem.classList.contains("asciimath")) {
    tag = "span";
    classList = "math-container inline-math ascii-math mathjax-math";
    content = `%${elem.textContent}%`;
  } else {
    return null;
  }

  const mathWrapper = document.createElement(tag);
  mathWrapper.classList.add(...classList.split(" "), CSS_CLASSES.HIDDEN);
  mathWrapper.textContent = content;

  elem.after(mathWrapper);

  return mathWrapper;
}

function resetMathJax(elem, opts) {
  const selector = opts.enable_asciimath ? ".math, .asciimath" : ".math";

  elem.querySelectorAll(selector).forEach((mathElem) => {
    mathElem.classList.remove(CSS_CLASSES.APPLIED_MATHJAX, CSS_CLASSES.HIDDEN);
  });

  elem
    .querySelectorAll(".math-container.mathjax-math")
    .forEach((wrapper) => wrapper.remove());
}

export function renderMathJax(elem, opts, renderOptions = {}) {
  if (!elem) {
    return;
  }

  if (renderOptions.force) {
    resetMathJax(elem, opts);
  }

  const selector = opts.enable_asciimath ? ".math, .asciimath" : ".math";
  const mathElems = elem.querySelectorAll(selector);

  if (mathElems.length === 0) {
    return;
  }

  const isPreview = elem.classList.contains("d-editor-preview");

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

  if (wrappers.length === 0) {
    return;
  }

  later(
    async () => {
      try {
        const MathJax = await ensureMathJax(opts);

        const active = wrappers.filter(
          ({ original, wrapper }) =>
            wrapper?.isConnected &&
            original?.parentElement?.offsetParent !== null
        );

        if (active.length === 0 || !MathJax?.typesetPromise) {
          return;
        }

        await MathJax.typesetPromise(active.map(({ wrapper }) => wrapper));

        active.forEach(({ original, wrapper }) => {
          if (original?.isConnected) {
            original.classList.add(CSS_CLASSES.HIDDEN);
          }

          if (wrapper?.isConnected) {
            wrapper.classList.remove(CSS_CLASSES.HIDDEN);
          }
        });
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error("MathJax rendering failed:", error);

        // On error, show original elements and remove failed wrappers
        wrappers.forEach(({ original, wrapper }) => {
          if (original?.isConnected) {
            original.classList.remove(
              CSS_CLASSES.HIDDEN,
              CSS_CLASSES.APPLIED_MATHJAX
            );
          }
          if (wrapper?.isConnected) {
            wrapper.remove();
          }
        });
      }
    },
    // Delay rendering in preview to debounce rapid typing and avoid
    // layout thrashing while the user is still editing
    isPreview ? 200 : 0
  );
}

async function ensureKaTeX() {
  try {
    await loadKaTeX({
      enableMhchem: true,
      enableCopyTex: true,
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("Failed to load KaTeX dependencies:", error);
    throw error;
  }
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
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("KaTeX rendering failed for expression:", text, error);
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
    // Error already logged in ensureKaTeX
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

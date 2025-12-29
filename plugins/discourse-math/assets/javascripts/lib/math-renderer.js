import { later } from "@ember/runloop";
import { getURLWithCDN } from "discourse/lib/get-url";
import loadMathJax from "discourse/lib/load-mathjax";
import loadScript from "discourse/lib/load-script";

/**
 * @typedef {Object} DiscourseMathOptions
 * @property {boolean} enabled
 * @property {"mathjax" | "katex"} provider
 * @property {boolean} enable_asciimath
 * @property {boolean} enable_accessibility
 * @property {"html" | "svg"} mathjax_output
 * @property {boolean} zoom_on_hover
 */

let initializedMathJax = false;

/**
 * @param {import("discourse/services/site-settings").default} siteSettings
 * @returns {DiscourseMathOptions}
 */
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

/**
 * @param {DiscourseMathOptions} opts
 * @returns {void}
 */
function initMathJax(opts) {
  if (initializedMathJax) {
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

  window.MathJax = {
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
        const readyResult = MathJax?.startup?.defaultReady?.();
        return readyResult;
      },
    },
  };

  initializedMathJax = true;
}

/**
 * @param {DiscourseMathOptions} opts
 * @returns {Promise<unknown>}
 */
function ensureMathJax(opts) {
  initMathJax(opts);
  return loadMathJax({
    enableAsciimath: opts.enable_asciimath,
    enableAccessibility: opts.enable_accessibility,
    output: opts.mathjax_output,
  });
}

/**
 * @param {Element} elem
 * @returns {HTMLElement | null}
 */
function buildMathJaxWrapper(elem) {
  let tag, classList, content;

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
  mathWrapper.classList.add(...classList.split(" "));
  mathWrapper.style.display = "none";
  mathWrapper.textContent = content;

  elem.after(mathWrapper);

  return mathWrapper;
}

/**
 * @param {Element} elem
 * @param {DiscourseMathOptions} opts
 * @returns {void}
 */
function resetMathJax(elem, opts) {
  const selector = opts.enable_asciimath ? ".math, .asciimath" : ".math";

  elem.querySelectorAll(selector).forEach((mathElem) => {
    delete mathElem.dataset.appliedMathjax;
    mathElem.style.display = null;
  });

  elem
    .querySelectorAll(".math-container.mathjax-math")
    .forEach((wrapper) => wrapper.remove());
}

/**
 * @param {Element} elem
 * @param {DiscourseMathOptions} opts
 * @param {{ force?: boolean }} [renderOptions]
 * @returns {void}
 */
export function renderMathJax(elem, opts, renderOptions = {}) {
  if (!elem) {
    return;
  }

  if (renderOptions.force) {
    resetMathJax(elem, opts);
  }

  let mathElems;
  if (opts.enable_asciimath) {
    mathElems = elem.querySelectorAll(".math, .asciimath");
  } else {
    mathElems = elem.querySelectorAll(".math");
  }

  if (mathElems.length > 0) {
    const isPreview = elem.classList.contains("d-editor-preview");
    const wrappers = [];

    mathElems.forEach((mathElem) => {
      if (mathElem.dataset.appliedMathjax) {
        return;
      }

      mathElem.dataset.appliedMathjax = true;
      const wrapper = buildMathJaxWrapper(mathElem);

      if (wrapper) {
        wrappers.push({ original: mathElem, wrapper });
      }
    });

    if (!wrappers.length) {
      return;
    }

    later(
      () => {
        ensureMathJax(opts).then((MathJax) => {
          const active = wrappers.filter(
            ({ original, wrapper }) =>
              wrapper?.isConnected &&
              original?.parentElement?.offsetParent !== null
          );

          if (!active.length || !MathJax?.typesetPromise) {
            return;
          }

          MathJax.typesetPromise(active.map(({ wrapper }) => wrapper)).then(
            () => {
              active.forEach(({ original, wrapper }) => {
                if (original?.isConnected) {
                  original.style.display = "none";
                }

                if (wrapper?.isConnected) {
                  wrapper.style.display = null;
                }
              });
            }
          );
        });
      },
      isPreview ? 200 : 0
    );
  }
}

/**
 * @returns {Promise<void>}
 */
async function ensureKaTeX() {
  try {
    await loadScript("/plugins/discourse-math/katex/katex.min.js");
    await loadScript("/plugins/discourse-math/katex/katex.min.css", {
      css: true,
    });
    await loadScript("/plugins/discourse-math/katex/mhchem.min.js");
    await loadScript("/plugins/discourse-math/katex/copy-tex.min.js");
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("Failed to load KaTeX dependencies.", e);
  }
}

/**
 * @param {Element} elem
 * @returns {void}
 */
function resetKatex(elem) {
  elem.querySelectorAll(".math").forEach((mathElem) => {
    delete mathElem.dataset.appliedKatex;
    mathElem.classList.remove(
      "math-container",
      "inline-math",
      "block-math",
      "katex-math"
    );
  });
}

/**
 * @param {Element} elem
 * @param {Record<string, unknown>} katexOpts
 * @returns {void}
 */
function decorateKatex(elem, katexOpts) {
  katexOpts.displayMode = elem.tagName === "DIV";

  if (elem.dataset.appliedKatex) {
    return;
  }

  elem.dataset.appliedKatex = true;

  if (!elem.classList.contains("math")) {
    return;
  }

  const tag = elem.tagName === "DIV" ? "div" : "span";
  const displayClass = tag === "div" ? "block-math" : "inline-math";
  const text = elem.textContent;
  elem.classList.add("math-container", displayClass, "katex-math");
  elem.textContent = "";
  window.katex.render(text, elem, katexOpts);
}

/**
 * @param {Element} elem
 * @param {{ force?: boolean }} [renderOptions]
 * @returns {Promise<void>}
 */
export async function renderKatex(elem, renderOptions = {}) {
  if (!elem) {
    return;
  }

  const mathElems = elem.querySelectorAll(".math");
  if (!mathElems.length > 0) {
    return;
  }

  if (renderOptions.force) {
    resetKatex(elem);
  }

  await ensureKaTeX();

  // enable persistent macros with are disabled by default: https://katex.org/docs/api.html#persistent-macros
  // also enable equation labelling and referencing which are disabled by default
  // both of these are enabled in mathjax by default, so now the katex implementation is (more) mathjax compatible
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

/**
 * @param {Element} elem
 * @param {DiscourseMathOptions} opts
 * @param {{ force?: boolean }} [renderOptions]
 * @returns {void}
 */
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

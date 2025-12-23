import { later, next } from "@ember/runloop";
import { getURLWithCDN } from "discourse/lib/get-url";
import loadMathJax from "discourse/lib/load-mathjax";
import { withPluginApi } from "discourse/lib/plugin-api";

let initializedMathJax = false;

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

function ensureMathJax(opts) {
  initMathJax(opts);
  return loadMathJax({
    enableAsciimath: opts.enable_asciimath,
    enableAccessibility: opts.enable_accessibility,
    output: opts.mathjax_output,
  });
}

function buildWrapper(elem) {
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

function mathjax(elem, opts) {
  if (!elem) {
    return;
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
      const wrapper = buildWrapper(mathElem);

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

function initializeMath(api, discourseMathOptions) {
  api.decorateCookedElement(
    (element) => {
      next(() => {
        mathjax(element, discourseMathOptions);
      });
    },
    { id: "mathjax" }
  );

  if (api.decorateChatMessage) {
    api.decorateChatMessage(
      (element) => {
        mathjax(element, discourseMathOptions);
      },
      {
        id: "mathjax-chat",
      }
    );
  }
}

export default {
  name: "apply-math-mathjax",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    let discourse_math_opts = {
      zoom_on_hover: siteSettings.discourse_math_zoom_on_hover,
      enable_accessibility: siteSettings.discourse_math_enable_accessibility,
      enable_asciimath: siteSettings.discourse_math_enable_asciimath,
      mathjax_output: siteSettings.discourse_math_mathjax_output,
    };
    if (
      siteSettings.discourse_math_enabled &&
      siteSettings.discourse_math_provider === "mathjax"
    ) {
      withPluginApi(function (api) {
        initializeMath(api, discourse_math_opts);
      });
    }
  },
};

import { later, next } from "@ember/runloop";
import { getURLWithCDN } from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";

let initializedMathJax = false;

function initMathJax(opts) {
  if (initializedMathJax) {
    return;
  }

  const extensions = ["toMathML.js", "Safe.js"];

  if (opts.enable_accessibility) {
    extensions.push("[a11y]/accessibility-menu.js");
  }

  let settings = {
    jax: ["input/TeX", "input/AsciiMath", "input/MathML", "output/CommonHTML"],
    TeX: { extensions: ["AMSmath.js", "AMSsymbols.js", "autoload-all.js"] },
    extensions,
    showProcessingMessages: false,
    messageStyle: "none",
    root: getURLWithCDN("/plugins/discourse-math/mathjax"),
  };

  if (opts.zoom_on_hover) {
    settings.menuSettings = { zoom: "Hover" };
    settings.MathEvents = { hover: 750 };
  }
  window.MathJax = settings;
  initializedMathJax = true;
}

function ensureMathJax(opts) {
  initMathJax(opts);
  return loadScript("/plugins/discourse-math/mathjax/MathJax.2.7.5.js");
}

function decorate(elem, isPreview) {
  if (elem.dataset.appliedMathjax) {
    return;
  }

  elem.dataset.appliedMathjax = true;

  let tag, classList, type;

  if (elem.classList.contains("math")) {
    tag = elem.tagName === "DIV" ? "div" : "span";
    const display = tag === "div" ? "; mode=display" : "";
    const displayClass = tag === "div" ? "block-math" : "inline-math";
    type = `math/tex${display}`;
    classList = `math-container ${displayClass} mathjax-math`;
  } else if (elem.classList.contains("asciimath")) {
    tag = "span";
    classList = "math-container inline-math ascii-math";
    type = "math/asciimath";
  }

  const mathScript = document.createElement("script");
  mathScript.type = type;
  mathScript.innerText = elem.textContent;

  const mathWrapper = document.createElement(tag);
  mathWrapper.classList.add(classList.split(" "));
  mathWrapper.style.display = "none";

  mathWrapper.appendChild(mathScript);

  elem.after(mathWrapper);

  later(
    this,
    () => {
      window.MathJax.Hub.Queue(() => {
        // don't bother processing previews removed from DOM
        if (elem?.parentElement?.offsetParent !== null) {
          window.MathJax.Hub.Typeset(mathScript, () => {
            elem.style.display = "none";
            mathWrapper.style.display = null;
          });
        }
      });
    },
    isPreview ? 200 : 0
  );
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

    ensureMathJax(opts).then(() => {
      mathElems.forEach((mathElem) => decorate(mathElem, isPreview));
    });
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
    };
    if (
      siteSettings.discourse_math_enabled &&
      siteSettings.discourse_math_provider === "mathjax"
    ) {
      withPluginApi("0.5", function (api) {
        initializeMath(api, discourse_math_opts);
      });
    }
  },
};

import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";

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

function decorate(elem, katexOpts) {
  katexOpts["displayMode"] = elem.tagName === "DIV";

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

async function katex(elem) {
  if (!elem) {
    return;
  }

  const mathElems = elem.querySelectorAll(".math");
  if (!mathElems.length > 0) {
    return;
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
  mathElems.forEach((mathElem) => decorate(mathElem, katexOpts));
}

function initializeMath(api) {
  api.decorateCookedElement(
    function (elem) {
      katex(elem);
    },
    { id: "katex" }
  );

  if (api.decorateChatMessage) {
    api.decorateChatMessage(
      (element) => {
        katex(element);
      },
      { id: "katex-chat" }
    );
  }
}

export default {
  name: "apply-math-katex",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (
      siteSettings.discourse_math_enabled &&
      siteSettings.discourse_math_provider === "katex"
    ) {
      withPluginApi("0.5", function (api) {
        initializeMath(api);
      });
    }
  },
};

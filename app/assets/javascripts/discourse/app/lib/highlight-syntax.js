import loadScript from "discourse/lib/load-script";
import mergeHTMLPlugin from "discourse/lib/highlight-syntax-merge-html-plugin";

/*global hljs:true */
let _moreLanguages = [];
let _plugins = [];
let _selectors = new Set();
let _options = {};
let _initialized = false;

export default function highlightSyntax(
  elem,
  siteSettings,
  session,
  customSelector
) {
  if (!elem) {
    return;
  }

  const selector = siteSettings.autohighlight_all_code
    ? "pre code"
    : "pre code[class]";

  const finalSelector =
    customSelector || Array.from(new Set([selector, ..._selectors])).join(",");

  const codeblocks = elem.querySelectorAll(finalSelector);

  if (!codeblocks.length) {
    return;
  }

  const path = session.highlightJsPath;

  if (!path) {
    return;
  }

  return loadScript(path).then(() => {
    initializer();

    codeblocks.forEach((e) => {
      // Large code blocks can cause crashes or slowdowns
      if (e.innerHTML.length > 30000) {
        return;
      }

      e.classList.remove("lang-auto");
      hljs.highlightElement(e);
    });
  });
}

export function registerHighlightJSLanguage(name, fn) {
  _moreLanguages.push({ name, fn });
}

export function registerHighlightJSPlugin(plugin) {
  _plugins.push(plugin);
}

export function registerHighlightJSSelector(selector) {
  _selectors.add(selector);
}

export function registerHighlightJSConfigure(options) {
  _options = { ..._options, ...options };
}

function customHighlightJSLanguages() {
  _moreLanguages.forEach((l) => {
    if (hljs.getLanguage(l.name) === undefined) {
      hljs.registerLanguage(l.name, l.fn);
    }
  });
}

function customHighlightJSPlugins() {
  _plugins.forEach((p) => {
    hljs.addPlugin(p);
  });
}

function initializer() {
  if (!_initialized) {
    customHighlightJSLanguages();
    customHighlightJSPlugins();
    hljs.addPlugin(mergeHTMLPlugin);
    hljs.configure({
      ..._options,
      ignoreUnescapedHTML: true,
    });

    _initialized = true;
  }
}

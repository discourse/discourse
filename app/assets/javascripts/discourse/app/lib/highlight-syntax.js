import loadScript from "discourse/lib/load-script";
import mergeHTMLPlugin from "discourse/lib/highlight-syntax-merge-html-plugin";

/*global hljs:true */
let _moreLanguages = [];
let _plugins = [];
let _initialized = false;

export default function highlightSyntax(elem, siteSettings, session) {
  if (!elem) {
    return;
  }

  const selector = siteSettings.autohighlight_all_code
    ? "pre code"
    : "pre code[class]";

  const codeblocks = elem.querySelectorAll(selector);

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
      ignoreUnescapedHTML: true,
    });

    _initialized = true;
  }
}

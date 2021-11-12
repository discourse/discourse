import deprecated from "discourse-common/lib/deprecated";
import loadScript from "discourse/lib/load-script";

/*global hljs:true */
let _moreLanguages = [];

export default function highlightSyntax(elem, siteSettings, session) {
  if (!elem) {
    return;
  }

  const selector = siteSettings.autohighlight_all_code
    ? "pre code"
    : "pre code[class]";
  const path = session.highlightJsPath;

  // eslint-disable-next-line no-undef
  if (elem instanceof jQuery) {
    deprecated(
      "highlightSyntax now takes a DOM node instead of a jQuery object.",
      {
        since: "2.6.0",
        dropFrom: "2.7.0",
      }
    );

    elem = elem[0];
  }

  if (!path) {
    return;
  }

  return loadScript(path).then(() => {
    customHighlightJSLanguages();

    elem.querySelectorAll(selector).forEach((e) => {
      // Large code blocks can cause crashes or slowdowns
      if (e.innerHTML.length > 30000) {
        return;
      }

      e.classList.remove("lang-auto");
      hljs.highlightBlock(e);
    });
  });
}

export function registerHighlightJSLanguage(name, fn) {
  _moreLanguages.push({ name, fn });
}

function customHighlightJSLanguages() {
  _moreLanguages.forEach((l) => {
    if (hljs.getLanguage(l.name) === undefined) {
      hljs.registerLanguage(l.name, l.fn);
    }
  });
}

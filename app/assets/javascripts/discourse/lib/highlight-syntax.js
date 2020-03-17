/*global hljs:true */
let _moreLanguages = [];

import loadScript from "discourse/lib/load-script";

export default function highlightSyntax($elem) {
  const selector = Discourse.SiteSettings.autohighlight_all_code
      ? "pre code"
      : "pre code[class]",
    path = Discourse.HighlightJSPath;

  if (!path) {
    return;
  }

  $(selector, $elem).each(function(i, e) {
    $(e).removeClass("lang-auto");
    loadScript(path).then(() => {
      customHighlightJSLanguages();
      hljs.highlightBlock(e);
    });
  });
}

export function registerHighlightJSLanguage(name, fn) {
  _moreLanguages.push({ name: name, fn: fn });
}

function customHighlightJSLanguages() {
  _moreLanguages.forEach(l => {
    if (hljs.getLanguage(l.name) === undefined) {
      hljs.registerLanguage(l.name, l.fn);
    }
  });
}

/*global hljs:true */

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
    loadScript(path).then(() => hljs.highlightBlock(e));
  });
}

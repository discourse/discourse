/*global hljs:true */

import loadScript from 'discourse/lib/load-script';

export default function highlightSyntax($elem) {
  const selector = Discourse.SiteSettings.autohighlight_all_code ? 'pre code' : 'pre code[class]';
  $(selector, $elem).each(function(i, e) {
    loadScript(Discourse.HighlightJSPath).then(() => hljs.highlightBlock(e));
  });
}

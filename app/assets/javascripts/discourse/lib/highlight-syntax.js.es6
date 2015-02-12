/*global hljs:true */

export default function highlightSyntax($elem) {
  const selector = Discourse.SiteSettings.autohighlight_all_code ? 'pre code' : 'pre code[class]';
  $(selector, $elem).each(function(i, e) {
    return $LAB.script("/javascripts/highlight.pack.js").wait(function() {
      return hljs.highlightBlock(e);
    });
  });
}

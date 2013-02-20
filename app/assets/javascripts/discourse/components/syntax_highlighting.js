/*global hljs:true */

/* Helper object for syntax highlighting. Uses highlight.js which is loaded
   on demand. */
(function() {

  window.Discourse.SyntaxHighlighting = {
    apply: function($elem) {
      var _this = this;
      return jQuery('pre code[class]', $elem).each(function(i, e) {
        return $LAB.script("/javascripts/highlight-handlebars.pack.js").wait(function() {
          return hljs.highlightBlock(e);
        });
      });
    }
  };

}).call(this);

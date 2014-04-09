/*global hljs:true */

/**
  Helper object for syntax highlighting. Uses highlight.js which is loaded on demand.

  @class SyntaxHighlighting
  @namespace Discourse
  @module Discourse
**/
Discourse.SyntaxHighlighting = {

  /**
    Apply syntax highlighting to a jQuery element

    @method apply
    @param {jQuery.selector} $elem The element we want to apply our highlighting to
  **/
  apply: function($elem) {
    var selector = Discourse.SiteSettings.autohighlight_all_code ? 'pre code' : 'pre code[class]';
    $(selector, $elem).each(function(i, e) {
      return $LAB.script("/javascripts/highlight.pack.js").wait(function() {
        return hljs.highlightBlock(e);
      });
    });
  }
};

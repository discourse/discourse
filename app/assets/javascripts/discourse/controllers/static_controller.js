/**
  This controller supports displaying static content.

  @class StaticController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.StaticController = Discourse.Controller.extend({
  content: null,

  loadPath: function(path) {
    var $preloaded, text,
      _this = this;
    this.set('content', null);

    // Load from <noscript> if we have it.
    $preloaded = $("noscript[data-path=\"" + path + "\"]");
    if ($preloaded.length) {
      text = $preloaded.text();
      text = text.replace(/<header[\s\S]*<\/header\>/, '');
      return this.set('content', text);
    } else {
      return jQuery.ajax({
        url: "" + path + ".json",
        success: function(result) {
          return _this.set('content', result);
        }
      });
    }
  }
});

Discourse.StaticController.reopenClass({
  pages: ['faq', 'tos', 'privacy']
});



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
      text = text.match(/<!-- preload-content: -->((?:.|[\n\r])*)<!-- :preload-content -->/);
      text = text[1];
      return this.set('content', text);
    } else {
      return $.ajax({
        url: Discourse.getURL("" + path + ".json"),
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



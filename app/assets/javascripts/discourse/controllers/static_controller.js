/**
  This controller supports displaying static content.

  @class StaticController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.StaticController = Discourse.Controller.extend({

  loadPath: function(path) {
    var staticController = this;
    this.set('content', null);

    // Load from <noscript> if we have it.
    var $preloaded = $("noscript[data-path=\"" + path + "\"]");
    if ($preloaded.length) {
      var text = $preloaded.text();
      text = text.match(/<!-- preload-content: -->((?:.|[\n\r])*)<!-- :preload-content -->/);
      text = text[1];
      this.set('content', text);
    } else {
      return Discourse.ajax(path + ".json", {dataType: 'html'}).then(function (result) {
        staticController.set('content', result);
      });
    }
  }
});

Discourse.StaticController.reopenClass({
  pages: ['faq', 'tos', 'privacy', 'login']
});



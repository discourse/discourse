/**
  This controller supports displaying static content.

  @class StaticController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.StaticController = Discourse.Controller.extend({
  needs: ['header'],
  path: null,

  showLoginButton: function() {
    return this.get('path') === '/login';
  }.property('path'),

  loadPath: function(path) {
    this.set('path', path);
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
      return Discourse.ajax(path, {dataType: 'html'}).then(function (result) {
        staticController.set('content', result);
      });
    }
  }
});

Discourse.StaticController.reopenClass({
  pages: ['faq', 'tos', 'privacy', 'login'],
  configs: {
    'faq': 'faq_url',
    'tos': 'tos_url',
    'privacy': 'privacy_policy_url'
  }
});



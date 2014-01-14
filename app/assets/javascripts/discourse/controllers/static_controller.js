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
    var self = this;

    this.setProperties({
      path: path,
      content: null
    });

    // Load from <noscript> if we have it.
    var $preloaded = $("noscript[data-path=\"" + path + "\"]");
    if ($preloaded.length) {
      var text = $preloaded.text();
      text = text.match(/<!-- preload-content: -->((?:.|[\n\r])*)<!-- :preload-content -->/)[1];
      this.set('content', text);
    } else {
      return Discourse.ajax(path, {dataType: 'html'}).then(function (result) {
        self.set('content', result);
      });
    }
  }
});

Discourse.StaticController.reopenClass({
  PAGES: ['faq', 'tos', 'privacy', 'login'],
  CONFIGS: {
    'faq': 'faq_url',
    'tos': 'tos_url',
    'privacy': 'privacy_policy_url'
  }
});

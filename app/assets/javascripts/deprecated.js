(function() {
  var Discourse = require('discourse').default;

  Discourse.Markdown = {
    whiteListTag: Ember.K,
    whiteListIframe: Ember.K
  };

  Discourse.Dialect = {
    inlineRegexp: Ember.K,
    addPreProcessor: Ember.K,
    replaceBlock: Ember.K,
    inlineReplace: Ember.K,
    registerInline: Ember.K,
    registerEmoji: Ember.K
  };

  Discourse.ajax = function() {
    var ajax = require('discourse/lib/ajax').ajax;
    Ember.warn("Discourse.ajax is deprecated. Import the module and use it instead");
    return ajax.apply(this, arguments);
  };

  window.Discourse = Discourse;
})();

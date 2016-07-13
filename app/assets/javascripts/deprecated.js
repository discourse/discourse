(function() {
  var Discourse = require('discourse').default;

  function deprecate(module, methods) {
    const result = {};

    methods.forEach(function(m) {
      result[m] = function() {
        Ember.warn("Discourse." + module + "." + m + " is deprecated. Export a setup() function instead");
      };
    });

    Discourse[module] = result;
  }

  deprecate('Markdown', ['whiteListTag', 'whiteListIframe']);
  deprecate('Dialect',  ['inlineRegexp', 'inlineBetween', 'addPreProcessor', 'replaceBlock',
                         'inlineReplace', 'registerInline', 'registerEmoji']);

  deprecate('BBCode', ['replaceBBCode', 'register', 'rawBBCode', 'replaceBBCodeParamsRaw']);

  Discourse.dialect_deprecated = true;

  Discourse.ajax = function() {
    var ajax = require('discourse/lib/ajax').ajax;
    Ember.warn("Discourse.ajax is deprecated. Import the module and use it instead");
    return ajax.apply(this, arguments);
  };

  window.Discourse = Discourse;
})();

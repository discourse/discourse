(function() {
  var Discourse = require('discourse').default;

  Discourse.dialect_deprecated = true;

  window.Discourse = Discourse;
})();

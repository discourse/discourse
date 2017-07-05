(function() {
  var Discourse = requirejs('discourse').default;

  Discourse.dialect_deprecated = true;

  window.Discourse = Discourse;
})();

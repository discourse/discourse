// ensure Discourse is added as a global
(function() {
  window.Discourse = requirejs('discourse').default;
})();

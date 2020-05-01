// discourse-skip-module

(function() {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }
  let Discourse = requirejs("discourse/app").default;

  // ensure Discourse is added as a global
  window.Discourse = Discourse;
})();

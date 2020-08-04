// discourse-skip-module

(function() {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }
  let Discourse = requirejs("discourse/app").default.create();

  // required for our template compiler
  window.__DISCOURSE_RAW_TEMPLATES = requirejs(
    "discourse-common/lib/raw-templates"
  ).__DISCOURSE_RAW_TEMPLATES;

  // ensure Discourse is added as a global
  window.Discourse = Discourse;
})();

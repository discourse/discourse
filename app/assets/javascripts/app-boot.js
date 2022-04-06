// discourse-skip-module

(function () {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }

  let Discourse = requirejs("discourse/app").default.create();

  // required for our template compiler
  window.__DISCOURSE_RAW_TEMPLATES = requirejs(
    "discourse-common/lib/raw-templates"
  ).__DISCOURSE_RAW_TEMPLATES;

  // required for addons to work without Ember CLI
  // eslint-disable-next-line no-undef
  Object.keys(Ember.TEMPLATES).forEach((k) => {
    if (k.indexOf("select-kit") === 0) {
      // eslint-disable-next-line no-undef
      let template = Ember.TEMPLATES[k];
      define(k, () => template);
    }
  });

  // ensure Discourse is added as a global
  window.Discourse = Discourse;
})();

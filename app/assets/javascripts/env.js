
// These will help us migrate up to the new ember's default behavior
window.ENV = {
  MANDATORY_SETTER: false,
  FEATURES: {'query-params-new': true}
};

window.Discourse = {};
Discourse.SiteSettings = {};

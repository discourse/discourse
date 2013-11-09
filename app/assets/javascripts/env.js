
// These will help us migrate up to the new ember's default behavior
window.ENV = {
  CP_DEFAULT_CACHEABLE: true,
  VIEW_PRESERVES_CONTEXT: true,
  MANDATORY_SETTER: false
};

window.Discourse = {};
Discourse.SiteSettings = {};

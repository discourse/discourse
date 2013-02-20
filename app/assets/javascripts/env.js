
/* These will help us migrate up to the new ember's default behavior
*/


(function() {

  window.ENV = {
    CP_DEFAULT_CACHEABLE: true,
    VIEW_PRESERVES_CONTEXT: true,
    MANDATORY_SETTER: false
  };

  window.Discourse = {};

  window.Discourse.SiteSettings = {};

}).call(this);

define("I18n", ["exports"], function (exports) {
  return I18n;
});

define("htmlbars-inline-precompile", ["exports"], function (exports) {
  exports.default = function tag(strings) {
    return Ember.Handlebars.compile(strings[0]);
  };
});

define("ember-addons/ember-computed-decorators", [
  "discourse-common/utils/decorators",
  "discourse-common/lib/deprecated",
], function (decorators, deprecated) {
  deprecated.default(
    "ember-addons/ember-computed-decorators is deprecated. Use discourse-common/utils/decorators instead.",
    { since: "2.4", dropFrom: "3.0" }
  );
  return decorators;
});

// Based on https://github.com/emberjs/ember-jquery-legacy
// The addon has out-of-date dependences, but it's super simple so we can reproduce here instead:
define("ember-jquery-legacy", ["exports"], function (exports) {
  exports.normalizeEvent = function (e) {
    if (e instanceof Event) {
      return e;
    }
    // __originalEvent is a private escape hatch of Ember's EventDispatcher to allow accessing `originalEvent` without
    // triggering a deprecation message.
    return e.__originalEvent || e.originalEvent;
  };
});

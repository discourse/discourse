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
    { since: "v2.4", dropFrom: "v3.0" }
  );
  return decorators;
});

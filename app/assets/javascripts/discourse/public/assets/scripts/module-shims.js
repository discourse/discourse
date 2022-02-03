define("I18n", ["exports"], function (exports) {
  return I18n;
});

define("htmlbars-inline-precompile", ["exports"], function (exports) {
  exports.default = function tag(strings) {
    return Ember.Handlebars.compile(strings[0]);
  };
});

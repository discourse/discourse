define("I18n", [
  "exports",
  "discourse-i18n",
  "discourse-common/lib/deprecated",
], function (exports, I18n, deprecated) {
  exports.default = I18n.default;

  exports.t = function () {
    deprecated.default(
      "Importing t from I18n is deprecated. Use the default export instead.",
      {
        id: "discourse.i18n-t-import",
      }
    );
    return I18n.default.t(...arguments);
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

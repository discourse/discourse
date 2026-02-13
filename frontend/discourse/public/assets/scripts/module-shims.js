define("I18n", [
  "exports",
  "discourse-i18n",
  "discourse/lib/deprecated",
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

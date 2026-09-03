import { module, test } from "qunit";
import { languageName } from "discourse/admin/lib/format-language";
import I18n from "discourse-i18n";

module("Unit | Admin | Lib | format-language", function (hooks) {
  let originalLocale;

  hooks.beforeEach(function () {
    originalLocale = I18n.locale;
    I18n.locale = "en";
  });

  hooks.afterEach(function () {
    I18n.locale = originalLocale;
  });

  test("formats browser language values", function (assert) {
    const cases = [
      [null, "", "missing language"],
      ["en", "English", "base language"],
      ["en-US", "American English", "language with region"],
      ["en-GB", "British English", "regional dialect"],
      ["zh-Hant-TW", "Chinese (Traditional, Taiwan)", "script and region"],
      ["sr-Latn-RS", "Serbian (Latin, Serbia)", "non-default script"],
      ["iw-IL", "Hebrew (Israel)", "legacy language code"],
      ["not_a_locale", "not_a_locale", "malformed language"],
    ];

    for (const [language, expected, description] of cases) {
      assert.strictEqual(languageName(language), expected, description);
    }
  });
});

import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  AUTOMATICALLY_TRANSLATE_COOKIE,
  automaticallyTranslate,
  languageSwitcherEnabled,
  normalizeUnderstoodLanguages,
} from "discourse/lib/content-localization";
import cookie, { removeCookie } from "discourse/lib/cookie";

module("Unit | Lib | content-localization", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    removeCookie(AUTOMATICALLY_TRANSLATE_COOKIE);
  });

  test("resolves the anonymous preference from the positive cookie", function (assert) {
    assert.true(
      automaticallyTranslate(),
      "automatic translation is enabled when no cookie exists"
    );

    cookie(AUTOMATICALLY_TRANSLATE_COOKIE, true);
    assert.true(
      automaticallyTranslate(),
      "the positive preference enables automatic translation"
    );

    cookie(AUTOMATICALLY_TRANSLATE_COOKIE, false);
    assert.false(
      automaticallyTranslate(),
      "the new false preference disables automatic translation"
    );
  });

  test("always resolves a logged-in user's preference without cookies", function (assert) {
    cookie(AUTOMATICALLY_TRANSLATE_COOKIE, false);

    assert.true(
      automaticallyTranslate({
        user_option: { automatically_translate: true },
      }),
      "the positive user preference wins over both cookies"
    );
    assert.false(
      automaticallyTranslate({
        user_option: { automatically_translate: false },
      }),
      "a disabled user preference wins over both cookies"
    );
  });

  test("normalizes understood languages independently from the interface language", function (assert) {
    assert.deepEqual(
      normalizeUnderstoodLanguages(["en", "de", "de"], "en"),
      ["en", "de"],
      "it removes duplicate languages"
    );
    assert.deepEqual(
      normalizeUnderstoodLanguages(["en"], "ja"),
      ["en"],
      "the interface language does not change explicit selections"
    );
  });

  test("resolves whether the language switcher is available", function (assert) {
    const settings = {
      content_localization_enabled: true,
      allow_user_locale: true,
      content_localization_language_switcher: "all",
      content_localization_supported_locales: "es|fr",
    };

    assert.true(
      languageSwitcherEnabled(settings),
      "a fully configured site offers the switcher"
    );
    assert.true(
      languageSwitcherEnabled({
        ...settings,
        content_localization_language_switcher: "anonymous",
      }),
      "the anonymous audience still counts as enabled"
    );
    assert.false(
      languageSwitcherEnabled({
        ...settings,
        content_localization_language_switcher: "none",
      }),
      "the switcher can be turned off"
    );
    assert.false(
      languageSwitcherEnabled({
        ...settings,
        content_localization_enabled: false,
      }),
      "it requires content localization"
    );
    assert.false(
      languageSwitcherEnabled({ ...settings, allow_user_locale: false }),
      "it requires user locales to be allowed"
    );
    assert.false(
      languageSwitcherEnabled({
        ...settings,
        content_localization_supported_locales: "",
      }),
      "it requires at least one configured locale"
    );
  });
});

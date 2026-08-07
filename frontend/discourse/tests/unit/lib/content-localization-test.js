import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  AUTOMATICALLY_TRANSLATE_COOKIE,
  automaticallyTranslate,
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
});

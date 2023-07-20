import { module, test } from "qunit";
import I18n from "I18n";
import LocalizationInitializer from "discourse/instance-initializers/localization";
import { setupTest } from "ember-qunit";

module("initializer:localization", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this._locale = I18n.locale;
    this._translations = I18n.translations;
    this._extras = I18n.extras;
    this._compiledMFs = I18n._compiledMFs;
    this._overrides = I18n._overrides;
    this._mfOverrides = I18n._mfOverrides;

    I18n.locale = "fr";

    I18n.translations = {
      fr: {
        js: {
          composer: {
            both_languages1: "composer.both_languages1 (FR)",
            both_languages2: "composer.both_languages2 (FR)",
          },
        },
      },
      en: {
        js: {
          composer: {
            both_languages1: "composer.both_languages1 (EN)",
            both_languages2: "composer.both_languages2 (EN)",
            only_english1: "composer.only_english1 (EN)",
            only_english2: "composer.only_english2 (EN)",
          },
        },
      },
    };

    I18n._compiledMFs = {
      "user.messages.some_key_MF": () => "user.messages.some_key_MF (FR)",
    };

    I18n.extras = {
      fr: {
        admin: {
          api: {
            both_languages1: "admin.api.both_languages1 (FR)",
            both_languages2: "admin.api.both_languages2 (FR)",
          },
        },
      },
      en: {
        admin: {
          api: {
            both_languages1: "admin.api.both_languages1 (EN)",
            both_languages2: "admin.api.both_languages2 (EN)",
            only_english1: "admin.api.only_english1 (EN)",
            only_english2: "admin.api.only_english2 (EN)",
          },
        },
      },
    };
  });

  hooks.afterEach(function () {
    I18n.locale = this._locale;
    I18n.translations = this._translations;
    I18n.extras = this._extras;
    I18n._compiledMFs = this._compiledMFs;
    I18n._overrides = this._overrides;
    I18n._mfOverrides = this._mfOverrides;
  });

  test("translation overrides", function (assert) {
    I18n._overrides = {
      fr: {
        "js.composer.both_languages1": "composer.both_languages1 (FR override)",
        "js.composer.only_english2": "composer.only_english2 (FR override)",
      },
      en: {
        "js.composer.both_languages2": "composer.both_languages2 (EN override)",
        "js.composer.only_english1": "composer.only_english1 (EN override)",
      },
    };
    LocalizationInitializer.initialize(this.owner);

    assert.strictEqual(
      I18n.t("composer.both_languages1"),
      "composer.both_languages1 (FR override)",
      "overrides existing translation in current locale"
    );

    assert.strictEqual(
      I18n.t("composer.only_english1"),
      "composer.only_english1 (EN override)",
      "overrides translation in fallback locale"
    );

    assert.strictEqual(
      I18n.t("composer.only_english2"),
      "composer.only_english2 (FR override)",
      "overrides translation that doesn't exist in current locale"
    );

    assert.strictEqual(
      I18n.t("composer.both_languages2"),
      "composer.both_languages2 (FR)",
      "prefers translation in current locale over override in fallback locale"
    );
  });

  test("translation overrides (admin_js)", function (assert) {
    I18n._overrides = {
      fr: {
        "admin_js.admin.api.both_languages1":
          "admin.api.both_languages1 (FR override)",
        "admin_js.admin.api.only_english2":
          "admin.api.only_english2 (FR override)",
        "admin_js.type_to_filter": "type_to_filter (FR override)",
      },
      en: {
        "admin_js.admin.api.both_languages2":
          "admin.api.both_languages2 (EN override)",
        "admin_js.admin.api.only_english1":
          "admin.api.only_english1 (EN override)",
      },
    };
    LocalizationInitializer.initialize(this.owner);

    assert.strictEqual(
      I18n.t("admin.api.both_languages1"),
      "admin.api.both_languages1 (FR override)",
      "overrides existing translation in current locale"
    );

    assert.strictEqual(
      I18n.t("admin.api.only_english1"),
      "admin.api.only_english1 (EN override)",
      "overrides translation in fallback locale"
    );

    assert.strictEqual(
      I18n.t("admin.api.only_english2"),
      "admin.api.only_english2 (FR override)",
      "overrides translation that doesn't exist in current locale"
    );

    assert.strictEqual(
      I18n.t("admin.api.both_languages2"),
      "admin.api.both_languages2 (FR)",
      "prefers translation in current locale over override in fallback locale"
    );

    assert.strictEqual(
      I18n.t("type_to_filter"),
      "type_to_filter (FR override)",
      "correctly changes the translation key by removing `admin_js`"
    );
  });

  test("translation overrides for MessageFormat strings", function (assert) {
    I18n._mfOverrides = {
      "js.user.messages.some_key_MF": () =>
        "user.messages.some_key_MF (FR override)",
    };

    LocalizationInitializer.initialize(this.owner);

    assert.strictEqual(
      I18n.messageFormat("user.messages.some_key_MF", {}),
      "user.messages.some_key_MF (FR override)",
      "overrides existing MessageFormat string"
    );
  });

  test("skip translation override if parent node is not an object", function (assert) {
    I18n._overrides = {
      fr: {
        "js.composer.both_languages1.foo":
          "composer.both_languages1.foo (FR override)",
      },
    };
    LocalizationInitializer.initialize(this.owner);

    assert.strictEqual(
      I18n.t("composer.both_languages1.foo"),
      "[fr.composer.both_languages1.foo]"
    );
  });
});

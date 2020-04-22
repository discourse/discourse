import LocalizationInitializer from "discourse/initializers/localization";

QUnit.module("initializer:localization", {
  _locale: I18n.locale,
  _translations: I18n.translations,
  _overrides: I18n._overrides,

  beforeEach() {
    I18n.locale = "fr";

    I18n.translations = {
      fr: {
        js: {
          composer: {
            reply: "Répondre"
          }
        }
      },
      en: {
        js: {
          topic: {
            reply: {
              help: "begin composing a reply to this topic"
            }
          }
        }
      }
    };
  },

  afterEach() {
    I18n.locale = this._locale;
    I18n.translations = this._translations;
    I18n._overrides = this._overrides;
  }
});

QUnit.test("translation overrides", function(assert) {
  I18n._overrides = {
    "js.composer.reply": "WAT",
    "js.topic.reply.help": "foobar"
  };
  LocalizationInitializer.initialize(this.registry);

  assert.equal(
    I18n.t("composer.reply"),
    "WAT",
    "overrides existing translation in current locale"
  );
  assert.equal(
    I18n.t("topic.reply.help"),
    "foobar",
    "overrides translation in default locale"
  );
});

QUnit.test(
  "skip translation override if parent node is not an object",
  function(assert) {
    I18n._overrides = {
      "js.composer.reply": "WAT",
      "js.composer.reply.help": "foobar"
    };
    LocalizationInitializer.initialize(this.registry);

    assert.equal(I18n.t("composer.reply.help"), "[fr.composer.reply.help]");
  }
);

module("lib:i18n", {
  _locale: I18n.locale,
  _translations: I18n.translations,

  setup() {
    I18n.locale = "fr";

    I18n.translations = {
      "fr": {
        "js": {
          "hello": "Bonjour",
          "topic": {
            "reply": {
              "title": "Répondre",
            }
          }
        }
      },
      "en": {
        "js": {
          "hello": {
            "world": "Hello World!"
          },
          "topic": {
            "reply": {
              "help": "begin composing a reply to this topic"
            }
          }
        }
      }
    };
  },

  teardown() {
    I18n.locale = this._locale;
    I18n.translations = this._translations;
  }
});

test("defaults", function() {
  equal(I18n.defaultLocale, "en", "it has English as default locale");
  ok(I18n.pluralizationRules["en"], "it has English pluralizer");
});

test("translations", function() {
  equal(I18n.t("topic.reply.title"), "Répondre", "uses locale translations when they exist");
  equal(I18n.t("topic.reply.help"), "begin composing a reply to this topic", "fallbacks to English translations");
  equal(I18n.t("hello.world"), "Hello World!", "doesn't break if a key is overriden in a locale");
});

test("extra translations", function() {
  I18n.extras = [{ "admin": { "title": "Discourse Admin" }}];

  equal(I18n.t("admin.title"), "Discourse Admin", "it check extra translations when they exists");
});

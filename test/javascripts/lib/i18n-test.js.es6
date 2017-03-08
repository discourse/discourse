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
          },
          "character_count": {
            "zero": "{{count}} ZERO",
            "one": "{{count}} ONE",
            "two": "{{count}} TWO",
            "few": "{{count}} FEW",
            "many": "{{count}} MANY",
            "other": "{{count}} OTHER"
          }
        }
      },
      "en": {
        "js": {
          "hello": {
            "world": "Hello World!",
            "universe": ""
          },
          "topic": {
            "reply": {
              "help": "begin composing a reply to this topic"
            }
          },
          "word_count": {
            "one": "1 word",
            "other": "{{count}} words"
          }
        }
      }
    };

    // fake pluralization rules
    I18n.pluralizationRules.fr = function(n) {
      if (n === 0) return "zero";
      if (n === 1) return "one";
      if (n === 2) return "two";
      if (n >=  3 && n <=  9) return "few";
      if (n >= 10 && n <= 99) return "many";
      return "other";
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
  equal(I18n.t("hello.universe"), "", "allows empty strings");
});

test("extra translations", function() {
  I18n.extras = [{ "admin": { "title": "Discourse Admin" }}];

  equal(I18n.t("admin.title"), "Discourse Admin", "it check extra translations when they exists");
});

test("pluralizations", function() {
  equal(I18n.t("character_count", { count: 0 }), "0 ZERO");
  equal(I18n.t("character_count", { count: 1 }), "1 ONE");
  equal(I18n.t("character_count", { count: 2 }), "2 TWO");
  equal(I18n.t("character_count", { count: 3 }), "3 FEW");
  equal(I18n.t("character_count", { count: 10 }), "10 MANY");
  equal(I18n.t("character_count", { count: 100 }), "100 OTHER");

  equal(I18n.t("word_count", { count: 0 }), "0 words");
  equal(I18n.t("word_count", { count: 1 }), "1 word");
  equal(I18n.t("word_count", { count: 2 }), "2 words");
  equal(I18n.t("word_count", { count: 3 }), "3 words");
  equal(I18n.t("word_count", { count: 10 }), "10 words");
  equal(I18n.t("word_count", { count: 100 }), "100 words");
});

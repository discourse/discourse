QUnit.module("lib:i18n", {
  _locale: I18n.locale,
  _fallbackLocale: I18n.fallbackLocale,
  _translations: I18n.translations,

  beforeEach() {
    I18n.locale = "fr";

    I18n.translations = {
      fr_FOO: {
        js: {
          topic: {
            reply: {
              title: "Foo"
            }
          }
        }
      },
      fr: {
        js: {
          hello: "Bonjour",
          topic: {
            reply: {
              title: "Répondre"
            },
            share: {
              title: "Partager"
            }
          },
          character_count: {
            zero: "{{count}} ZERO",
            one: "{{count}} ONE",
            two: "{{count}} TWO",
            few: "{{count}} FEW",
            many: "{{count}} MANY",
            other: "{{count}} OTHER"
          }
        }
      },
      en: {
        js: {
          hello: {
            world: "Hello World!",
            universe: ""
          },
          topic: {
            reply: {
              help: "begin composing a reply to this topic"
            }
          },
          word_count: {
            one: "1 word",
            other: "{{count}} words"
          }
        }
      }
    };

    // fake pluralization rules
    I18n.pluralizationRules.fr = function(n) {
      if (n === 0) return "zero";
      if (n === 1) return "one";
      if (n === 2) return "two";
      if (n >= 3 && n <= 9) return "few";
      if (n >= 10 && n <= 99) return "many";
      return "other";
    };
  },

  afterEach() {
    I18n.locale = this._locale;
    I18n.fallbackLocale = this._fallbackLocale;
    I18n.translations = this._translations;
  }
});

QUnit.test("defaults", assert => {
  assert.equal(I18n.defaultLocale, "en", "it has English as default locale");
  assert.ok(I18n.pluralizationRules["en"], "it has English pluralizer");
});

QUnit.test("translations", assert => {
  assert.equal(
    I18n.t("topic.reply.title"),
    "Répondre",
    "uses locale translations when they exist"
  );
  assert.equal(
    I18n.t("topic.reply.help"),
    "begin composing a reply to this topic",
    "fallbacks to English translations"
  );
  assert.equal(
    I18n.t("hello.world"),
    "Hello World!",
    "doesn't break if a key is overriden in a locale"
  );
  assert.equal(I18n.t("hello.universe"), "", "allows empty strings");
});

QUnit.test("extra translations", assert => {
  I18n.extras = [{ admin: { title: "Discourse Admin" } }];

  assert.equal(
    I18n.t("admin.title"),
    "Discourse Admin",
    "it check extra translations when they exists"
  );
});

QUnit.test("pluralizations", assert => {
  assert.equal(I18n.t("character_count", { count: 0 }), "0 ZERO");
  assert.equal(I18n.t("character_count", { count: 1 }), "1 ONE");
  assert.equal(I18n.t("character_count", { count: 2 }), "2 TWO");
  assert.equal(I18n.t("character_count", { count: 3 }), "3 FEW");
  assert.equal(I18n.t("character_count", { count: 10 }), "10 MANY");
  assert.equal(I18n.t("character_count", { count: 100 }), "100 OTHER");

  assert.equal(I18n.t("word_count", { count: 0 }), "0 words");
  assert.equal(I18n.t("word_count", { count: 1 }), "1 word");
  assert.equal(I18n.t("word_count", { count: 2 }), "2 words");
  assert.equal(I18n.t("word_count", { count: 3 }), "3 words");
  assert.equal(I18n.t("word_count", { count: 10 }), "10 words");
  assert.equal(I18n.t("word_count", { count: 100 }), "100 words");
});

QUnit.test("fallback", assert => {
  I18n.locale = "fr_FOO";
  I18n.fallbackLocale = "fr";

  assert.equal(
    I18n.t("topic.reply.title"),
    "Foo",
    "uses locale translations when they exist"
  );
  assert.equal(
    I18n.t("topic.share.title"),
    "Partager",
    "falls back to fallbackLocale translations when they exist"
  );
  assert.equal(
    I18n.t("topic.reply.help"),
    "begin composing a reply to this topic",
    "falls back to English translations"
  );
});

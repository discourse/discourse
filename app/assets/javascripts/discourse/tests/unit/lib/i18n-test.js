import { module, test } from "qunit";
import I18n from "I18n";

module("Unit | Utility | i18n", function (hooks) {
  hooks.beforeEach(function () {
    this._locale = I18n.locale;
    this._fallbackLocale = I18n.fallbackLocale;
    this._translations = I18n.translations;
    this._extras = I18n.extras;
    this._pluralizationRules = Object.assign({}, I18n.pluralizationRules);

    I18n.locale = "fr";

    I18n.translations = {
      fr_FOO: {
        js: {
          topic: {
            reply: {
              title: "Foo",
            },
          },
        },
      },
      fr: {
        js: {
          hello: "Bonjour",
          topic: {
            reply: {
              title: "Répondre",
            },
            share: {
              title: "Partager",
            },
          },
          character_count: {
            zero: "{{count}} ZERO",
            one: "{{count}} ONE",
            two: "{{count}} TWO",
            few: "{{count}} FEW",
            many: "{{count}} MANY",
            other: "{{count}} OTHER",
          },
          days: {
            other: "%{count} jours",
          },
        },
      },
      en: {
        js: {
          hello: {
            world: "Hello World!",
            universe: "",
          },
          topic: {
            reply: {
              help: "begin composing a reply to this topic",
            },
          },
          word_count: {
            one: "1 word",
            other: "{{count}} words",
          },
          days: {
            one: "%{count} day",
            other: "%{count} days",
          },
          dollar_sign: "Hi {{description}}",
        },
      },
    };

    // fake pluralization rules
    I18n.pluralizationRules = Object.assign({}, I18n.pluralizationRules);
    I18n.pluralizationRules.fr = function (n) {
      if (n === 0) {
        return "zero";
      }
      if (n === 1) {
        return "one";
      }
      if (n === 2) {
        return "two";
      }
      if (n >= 3 && n <= 9) {
        return "few";
      }
      if (n >= 10 && n <= 99) {
        return "many";
      }
      return "other";
    };
  });

  hooks.afterEach(function () {
    I18n.locale = this._locale;
    I18n.fallbackLocale = this._fallbackLocale;
    I18n.translations = this._translations;
    I18n.extras = this._extras;
    I18n.pluralizationRules = this._pluralizationRules;
  });

  test("defaults", function (assert) {
    assert.strictEqual(
      I18n.defaultLocale,
      "en",
      "it has English as default locale"
    );
    assert.ok(I18n.pluralizationRules["en"], "it has English pluralizer");
  });

  test("translations", function (assert) {
    assert.strictEqual(
      I18n.t("topic.reply.title"),
      "Répondre",
      "uses locale translations when they exist"
    );
    assert.strictEqual(
      I18n.t("topic.reply.help"),
      "begin composing a reply to this topic",
      "fallbacks to English translations"
    );
    assert.strictEqual(
      I18n.t("hello.world"),
      "Hello World!",
      "doesn't break if a key is overridden in a locale"
    );
    assert.strictEqual(I18n.t("hello.universe"), "", "allows empty strings");
  });

  test("extra translations", function (assert) {
    I18n.locale = "pl_PL";
    I18n.extras = {
      en: {
        admin: {
          dashboard: {
            title: "Dashboard",
            backup_count: {
              one: "%{count} backup",
              other: "%{count} backups",
            },
          },
          web_hooks: {
            events: {
              incoming: {
                one: "There is a new event.",
                other: "There are %{count} new events.",
              },
            },
          },
        },
      },
      pl_PL: {
        admin: {
          dashboard: {
            title: "Raporty",
          },
          web_hooks: {
            events: {
              incoming: {
                one: "Istnieje nowe wydarzenie",
                few: "Istnieją %{count} nowe wydarzenia.",
                many: "Istnieje %{count} nowych wydarzeń.",
                other: "Istnieje %{count} nowych wydarzeń.",
              },
            },
          },
        },
      },
    };
    I18n.pluralizationRules.pl_PL = function (n) {
      if (n === 1) {
        return "one";
      }
      if (n % 10 >= 2 && n % 10 <= 4) {
        return "few";
      }
      if (n % 10 === 0) {
        return "many";
      }
      return "other";
    };

    assert.strictEqual(
      I18n.t("admin.dashboard.title"),
      "Raporty",
      "it uses extra translations when they exists"
    );

    assert.strictEqual(
      I18n.t("admin.web_hooks.events.incoming", { count: 2 }),
      "Istnieją 2 nowe wydarzenia.",
      "it uses pluralized extra translation when it exists"
    );

    assert.strictEqual(
      I18n.t("admin.dashboard.backup_count", { count: 2 }),
      "2 backups",
      "it falls back to English and uses extra translations when they exists"
    );
  });

  test("pluralizations", function (assert) {
    assert.strictEqual(I18n.t("character_count", { count: 0 }), "0 ZERO");
    assert.strictEqual(I18n.t("character_count", { count: 1 }), "1 ONE");
    assert.strictEqual(I18n.t("character_count", { count: 2 }), "2 TWO");
    assert.strictEqual(I18n.t("character_count", { count: 3 }), "3 FEW");
    assert.strictEqual(I18n.t("character_count", { count: 10 }), "10 MANY");
    assert.strictEqual(I18n.t("character_count", { count: 100 }), "100 OTHER");

    assert.strictEqual(I18n.t("word_count", { count: 0 }), "0 words");
    assert.strictEqual(I18n.t("word_count", { count: 1 }), "1 word");
    assert.strictEqual(I18n.t("word_count", { count: 2 }), "2 words");
    assert.strictEqual(I18n.t("word_count", { count: 3 }), "3 words");
    assert.strictEqual(I18n.t("word_count", { count: 10 }), "10 words");
    assert.strictEqual(I18n.t("word_count", { count: 100 }), "100 words");
  });

  test("adds the count to the missing translation strings", function (assert) {
    assert.strictEqual(
      I18n.t("invalid_i18n_string", { count: 1 }),
      `[fr.invalid_i18n_string count=1]`
    );

    assert.strictEqual(
      I18n.t("character_count", { count: "0" }),
      `[fr.character_count count="0"]`
    );

    assert.strictEqual(
      I18n.t("character_count", { count: null }),
      `[fr.character_count count=null]`
    );

    assert.strictEqual(
      I18n.t("character_count", { count: undefined }),
      `[fr.character_count count=undefined]`
    );

    assert.strictEqual(I18n.t("character_count"), "[fr.character_count]");
  });

  test("fallback", function (assert) {
    assert.strictEqual(
      I18n.t("days", { count: 1 }),
      "1 day",
      "uses fallback locale for missing plural key"
    );
    assert.strictEqual(
      I18n.t("days", { count: 200 }),
      "200 jours",
      "uses existing French plural key"
    );

    I18n.locale = "fr_FOO";
    I18n.fallbackLocale = "fr";

    assert.strictEqual(
      I18n.t("topic.reply.title"),
      "Foo",
      "uses locale translations when they exist"
    );
    assert.strictEqual(
      I18n.t("topic.share.title"),
      "Partager",
      "falls back to fallbackLocale translations when they exist"
    );
    assert.strictEqual(
      I18n.t("topic.reply.help"),
      "begin composing a reply to this topic",
      "falls back to English translations"
    );
  });

  test("Dollar signs are properly escaped", function (assert) {
    assert.strictEqual(
      I18n.t("dollar_sign", {
        description: "$& $&",
      }),
      "Hi $& $&"
    );
  });
});

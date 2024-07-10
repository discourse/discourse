import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withSilencedDeprecations } from "discourse-common/lib/deprecated";
import I18n, { I18nMissingInterpolationArgument } from "discourse-i18n";

module("Unit | Utility | i18n", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this._locale = I18n.locale;
    this._fallbackLocale = I18n.fallbackLocale;
    this._translations = I18n.translations;
    this._extras = I18n.extras;
    this._pluralizationRules = { ...I18n.pluralizationRules };

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
          with_multiple_interpolate_arguments: "Hi %{username}, %{username2}",
        },
      },
      ja: {
        js: {
          topic_stat_sentence_week: {
            other: "先週、新しいトピックが %{count} 件投稿されました。",
          },
        },
      },
    };

    // fake pluralization rules
    I18n.pluralizationRules = { ...I18n.pluralizationRules };
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

    I18n.locale = "ja";
    assert.strictEqual(
      I18n.t("topic_stat_sentence_week", { count: 0 }),
      "先週、新しいトピックが 0 件投稿されました。"
    );
    assert.strictEqual(
      I18n.t("topic_stat_sentence_week", { count: 1 }),
      "先週、新しいトピックが 1 件投稿されました。"
    );
    assert.strictEqual(
      I18n.t("topic_stat_sentence_week", { count: 2 }),
      "先週、新しいトピックが 2 件投稿されました。"
    );
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

  test("Customized missing translation string", function (assert) {
    assert.strictEqual(
      I18n.t("emoji_picker.customtest", {
        translatedFallback: "customtest",
      }),
      "customtest"
    );
  });

  test("legacy require support", function (assert) {
    withSilencedDeprecations("discourse.i18n-t-import", () => {
      const myI18n = require("I18n");
      assert.strictEqual(myI18n.t("topic.reply.title"), "Répondre");
    });
  });

  test("missing interpolation argument does not throw error when I18n.testing is `false`", function (assert) {
    assert.strictEqual(
      I18n.t("with_multiple_interpolate_arguments", { username: "username" }),
      "Hi username, [missing %{username2} value]"
    );
  });

  test("missing interpolation argument throws error when I18n.testing is true", function (assert) {
    try {
      I18n.testing = true;

      assert.throws(function () {
        I18n.t("with_multiple_interpolate_arguments", {
          username: "username",
        });
      }, new I18nMissingInterpolationArgument(
        "with_multiple_interpolate_arguments: [missing %{username2} value]"
      ));
    } finally {
      I18n.testing = false;
    }
  });

  test("pluralizationNormalizedLocale", function (assert) {
    I18n.locale = "pt";

    assert.strictEqual(
      I18n.pluralizationNormalizedLocale,
      "pt_PT",
      "returns 'pt_PT' for the 'pt' locale, this is a special case of the 'make-plural' lib."
    );

    Object.entries({
      pt_BR: "pt",
      en_GB: "en",
      bs_BA: "bs",
      "fr-BE": "fr",
    }).forEach(([raw, normalized]) => {
      I18n.locale = raw;
      assert.strictEqual(
        I18n.pluralizationNormalizedLocale,
        normalized,
        `returns '${normalized}' for '${raw}'`
      );
    });
  });
});

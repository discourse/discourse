import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { formatMinutesSeconds } from "discourse/lib/formatter";
import I18n from "discourse-i18n";

module("Unit | Lib | formatMinutesSeconds", function (hooks) {
  setupTest(hooks);

  test("formats whole seconds below a minute as Xs", function (assert) {
    assert.strictEqual(formatMinutesSeconds(0), "0s");
    assert.strictEqual(formatMinutesSeconds(59), "59s");
  });

  test("formats seconds with optional subsecond precision", function (assert) {
    assert.strictEqual(
      formatMinutesSeconds(0, { subsecondPrecision: 2 }),
      "0s"
    );
    assert.strictEqual(
      formatMinutesSeconds(0.001, { subsecondPrecision: 2 }),
      "< 0.01s"
    );
    assert.strictEqual(
      formatMinutesSeconds(0.126, { subsecondPrecision: 2 }),
      "0.13s"
    );
    assert.strictEqual(
      formatMinutesSeconds(1.99, { subsecondPrecision: 2 }),
      "1s"
    );
  });

  test("formats localized subsecond values", function (assert) {
    const locale = I18n.locale;
    const translations = I18n.translations;

    I18n.locale = "ru";
    I18n.translations = {
      ru: {
        js: {
          dates: {
            tiny: {
              less_than_x_seconds: { other: "< %{count} с" },
              x_seconds: { other: "%{count} с" },
            },
          },
          number: { format: { delimiter: " ", separator: "," } },
        },
      },
    };

    try {
      assert.strictEqual(
        formatMinutesSeconds(0.001, { subsecondPrecision: 2 }),
        "< 0,01 с"
      );
      assert.strictEqual(
        formatMinutesSeconds(0.126, { subsecondPrecision: 2 }),
        "0,13 с"
      );

      I18n.locale = "he";
      I18n.translations = {
        he: {
          js: {
            dates: {
              tiny: {
                less_than_x_seconds: {
                  one: "פחות משנייה",
                  other: "פחות מ־%{count} שניות",
                },
                x_seconds: {
                  one: "שנייה",
                  other: "%{count} שניות",
                },
              },
            },
          },
        },
      };

      assert.strictEqual(
        formatMinutesSeconds(0.001, { subsecondPrecision: 2 }),
        "פחות מ־0.01 שניות"
      );
      assert.strictEqual(
        formatMinutesSeconds(0.126, { subsecondPrecision: 2 }),
        "0.13 שניות"
      );
    } finally {
      I18n.locale = locale;
      I18n.translations = translations;
    }
  });

  test("formats a minute or more as Xm Ys with both units", function (assert) {
    assert.strictEqual(formatMinutesSeconds(60), "1m 0s");
    assert.strictEqual(formatMinutesSeconds(107), "1m 47s");
    assert.strictEqual(formatMinutesSeconds(1800), "30m 0s");
    assert.strictEqual(
      formatMinutesSeconds(60.99, { subsecondPrecision: 2 }),
      "1m 0s"
    );
  });
});

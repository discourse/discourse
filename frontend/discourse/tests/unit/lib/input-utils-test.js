import { module, test } from "qunit";
import { isNumeric, isValidInput, normalize } from "select-kit/lib/input-utils";

module("Unit | Lib | input-utils", function () {
  module("isValidInput", function () {
    test("returns false for non-input keys", function (assert) {
      const nonInputKeys = [
        "F1",
        "F12",
        "ArrowUp",
        "ArrowDown",
        "ArrowLeft",
        "ArrowRight",
        "Meta",
        "Alt",
        "Control",
        "Shift",
        "Delete",
        "Enter",
        "Escape",
        "Tab",
        "Space",
        "Insert",
        "Backspace",
      ];

      nonInputKeys.forEach((key) => {
        assert.false(
          isValidInput(key),
          `${key} should not be a valid input key`
        );
      });
    });

    test("returns true for input keys", function (assert) {
      const inputKeys = [
        "a",
        "z",
        "A",
        "Z",
        "0",
        "9",
        "!",
        "@",
        "#",
        "$",
        "%",
        "^",
        "&",
        "*",
        "(",
        ")",
        "-",
        "_",
        "+",
        "=",
        "[",
        "]",
        "{",
        "}",
        "|",
        "\\",
        ";",
        ":",
        "'",
        '"',
        ",",
        ".",
        "/",
        "?",
        "é",
        "ü",
        "ñ", // Testing non-ASCII characters
      ];

      inputKeys.forEach((key) => {
        assert.true(isValidInput(key), `${key} should be a valid input key`);
      });
    });

    test("handles null/undefined", function (assert) {
      assert.true(
        isValidInput(null),
        "null should be considered a valid input"
      );
      assert.true(
        isValidInput(undefined),
        "undefined should be considered a valid input"
      );
    });
  });

  module("isNumeric", function () {
    test("returns true for numeric values", function (assert) {
      const numericValues = [
        0,
        1,
        -1,
        1.5,
        -1.5,
        "0",
        "1",
        "-1",
        "1.5",
        "-1.5",
        "1e5",
        "-1e5",
      ];

      numericValues.forEach((value) => {
        assert.true(isNumeric(value), `${value} should be considered numeric`);
      });
    });

    test("returns false for non-numeric values", function (assert) {
      const nonNumericValues = [
        "",
        " ",
        "a",
        "1a",
        "a1",
        "1,000",
        NaN,
        Infinity,
        -Infinity,
        null,
        undefined,
        {},
        [],
        true,
        false,
      ];

      nonNumericValues.forEach((value) => {
        assert.false(
          isNumeric(value),
          `${value} (${typeof value}) should not be considered numeric`
        );
      });
    });
  });

  module("normalize", function () {
    test("converts to lowercase", function (assert) {
      assert.strictEqual(
        normalize("AbC"),
        "abc",
        "should convert to lowercase"
      );
      assert.strictEqual(
        normalize("ABC123"),
        "abc123",
        "should convert letters to lowercase and keep numbers"
      );
    });

    test("removes diacritics", function (assert) {
      assert.strictEqual(
        normalize("café"),
        "cafe",
        "should remove acute accent"
      );
      assert.strictEqual(
        normalize("naïve"),
        "naive",
        "should remove diaeresis"
      );
      assert.strictEqual(
        normalize("résumé"),
        "resume",
        "should remove all diacritics"
      );
      assert.strictEqual(normalize("piñata"), "pinata", "should remove tilde");
      assert.strictEqual(
        normalize("Crème Brûlée"),
        "creme brulee",
        "should lowercase and remove all diacritics"
      );
    });

    test("passes through nullish values", function (assert) {
      assert.strictEqual(normalize(""), "", "should handle empty string");
      assert.strictEqual(normalize(null), null, "should handle null");
      assert.strictEqual(
        normalize(undefined),
        undefined,
        "should handle undefined"
      );
    });

    test("preserves symbols and numbers", function (assert) {
      assert.strictEqual(
        normalize("Hello! 123"),
        "hello! 123",
        "should preserve symbols and numbers"
      );
      assert.strictEqual(
        normalize("@#$%^&*()"),
        "@#$%^&*()",
        "should preserve symbols"
      );
    });
  });
});

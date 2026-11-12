import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  parseAttributesString,
  serializeAttributes,
} from "discourse/lib/wrap-utils";

module("Unit | lib | wrap-utils", function (hooks) {
  setupTest(hooks);

  test("parseAttributesString", function (assert) {
    assert.deepEqual(parseAttributesString(""), {});
    assert.deepEqual(parseAttributesString("   "), {});
    assert.deepEqual(parseAttributesString("=toc"), { wrap: "toc" });
    assert.deepEqual(parseAttributesString("=toc id=123"), {
      wrap: "toc",
      id: "123",
    });
    assert.deepEqual(
      parseAttributesString("=toc url=https://example.com/a/b"),
      { wrap: "toc", url: "https://example.com/a/b" },
      "keeps unquoted values containing = and /"
    );
  });

  test("parseAttributesString with quoted values containing spaces", function (assert) {
    assert.deepEqual(
      parseAttributesString(
        `=theme-install-button repo-name="Homepage Feature"`
      ),
      { wrap: "theme-install-button", "repo-name": "Homepage Feature" },
      "reads a double-quoted value with spaces"
    );
    assert.deepEqual(
      parseAttributesString(` repo-name='Homepage Feature'`),
      { "repo-name": "Homepage Feature" },
      "reads a single-quoted value with spaces"
    );
    assert.deepEqual(
      parseAttributesString(` repo-name=“Homepage Feature”`),
      { "repo-name": "Homepage Feature" },
      "reads other quotation marks in parity with the markdown-it parser"
    );
  });

  test("serializeAttributes", function (assert) {
    assert.strictEqual(serializeAttributes({}), "");
    assert.strictEqual(serializeAttributes({ wrap: "toc" }), "=toc");
    assert.strictEqual(
      serializeAttributes({ wrap: "toc", id: "123" }),
      "=toc id=123"
    );
    assert.strictEqual(
      serializeAttributes({ id: "123" }),
      " id=123",
      "leading space when there is no wrap name"
    );
  });

  test("serializeAttributes quotes values containing spaces", function (assert) {
    assert.strictEqual(
      serializeAttributes({
        wrap: "theme-install-button",
        "repo-name": "Homepage Feature",
      }),
      `=theme-install-button repo-name="Homepage Feature"`,
      "wraps a value with spaces in double quotes"
    );
    assert.strictEqual(
      serializeAttributes({ wrap: "quote", title: `Design "Gems"` }),
      `=quote title='Design "Gems"'`,
      "picks a non-conflicting quote pair when the value contains quotes"
    );
  });

  test("round-trips a value containing spaces", function (assert) {
    const attrs = {
      wrap: "theme-install-button",
      "repo-name": "Homepage Feature",
      "repo-url":
        "https://github.com/discourse/discourse-homepage-feature-component",
    };

    assert.deepEqual(
      parseAttributesString(serializeAttributes(attrs)),
      attrs,
      "serialize then parse preserves a spaced value"
    );
  });
});

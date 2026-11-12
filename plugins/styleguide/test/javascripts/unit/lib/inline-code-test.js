import { module, test } from "qunit";
import inlineCode from "discourse/plugins/styleguide/discourse/lib/inline-code";

module("Unit | Lib | inline-code", function () {
  test("wraps a backticked span in code", function (assert) {
    assert.strictEqual(
      inlineCode("never mutates `@value`").toString(),
      "never mutates <code>@value</code>",
      "the marks are consumed and the span becomes an element"
    );
  });

  test("handles several spans in one string", function (assert) {
    assert.strictEqual(
      inlineCode("`@a` then `@b`").toString(),
      "<code>@a</code> then <code>@b</code>"
    );
  });

  test("escapes markup outside a span", function (assert) {
    assert.strictEqual(
      inlineCode("<script>alert(1)</script>").toString(),
      "&lt;script&gt;alert(1)&lt;/script&gt;",
      "text is escaped rather than trusted through"
    );
  });

  test("escapes markup inside a span", function (assert) {
    assert.strictEqual(
      inlineCode("pass `<img onerror=x>` here").toString(),
      "pass <code>&lt;img onerror=x&gt;</code> here",
      "the code wrapper never becomes an injection point"
    );
  });

  test("escapes quotes and ampersands", function (assert) {
    assert.strictEqual(
      inlineCode(`a & b "c" 'd'`).toString(),
      "a &amp; b &quot;c&quot; &#x27;d&#x27;"
    );
  });

  // The whole point of splitting before escaping: escaping first would turn the backtick into
  // an entity, so the pattern being searched for would already be gone.
  test("an unmatched backtick does not code-format the tail", function (assert) {
    assert.strictEqual(
      inlineCode("Pass `@value to the child").toString(),
      "Pass &#x60;@value to the child",
      "an odd backtick count renders as prose, keeping the stray mark visible"
    );
  });

  test("an unmatched backtick still escapes markup", function (assert) {
    assert.strictEqual(
      inlineCode("` <b>x</b>").toString(),
      "&#x60; &lt;b&gt;x&lt;/b&gt;",
      "the unbalanced path escapes as thoroughly as the paired one"
    );
  });

  test("handles empty and nullish input", function (assert) {
    assert.strictEqual(inlineCode("").toString(), "");
    assert.strictEqual(inlineCode(null).toString(), "");
    assert.strictEqual(inlineCode(undefined).toString(), "");
  });
});

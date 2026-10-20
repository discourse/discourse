import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { highlightQuote } from "discourse/lib/quote";

module("Unit | Utility | quote", function (hooks) {
  setupTest(hooks);

  test("highlightQuote matches across formatting and paragraphs", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML =
      "<p>Before. Hello <strong>bold</strong> <a href='#'>link</a></p>\n<p>two</p>\n<p>After.</p>";

    const highlights = highlightQuote(elem, "Hello bold link\n\ntwo");

    assert.deepEqual(
      highlights.map((highlight) => highlight.textContent),
      ["Hello", "bold", "link", "two"],
      "highlights each piece of the quote"
    );
    assert.true(
      highlights.every((h) => h.matches("span.quote-highlight")),
      "wraps text in highlight spans"
    );
    assert.strictEqual(
      elem.textContent,
      "Before. Hello bold link\ntwo\nAfter.",
      "keeps the text intact"
    );
  });

  test("highlightQuote prefers whole words", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML = "<p>Start with the artist, then the art section</p>";

    const [highlight] = highlightQuote(elem, "art");

    assert.strictEqual(
      highlight.previousSibling.textContent.slice(-4),
      "the ",
      "starts at the whole word"
    );
    assert.strictEqual(
      highlight.nextSibling.textContent,
      " section",
      "ends at the whole word"
    );
  });

  test("highlightQuote falls back to part of a word", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML = "<p>artist</p>";

    assert.deepEqual(
      highlightQuote(elem, "art").map((highlight) => highlight.textContent),
      ["art"],
      "falls back to the first occurrence"
    );
  });

  test("highlightQuote leaves SVG text alone", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML = "<p>Before</p><svg><text>label</text></svg><p>after</p>";

    const highlights = highlightQuote(elem, "Before label after");

    assert.deepEqual(
      highlights.map((highlight) => highlight.textContent),
      ["Before", "after"],
      "highlights the text around the SVG"
    );
    assert
      .dom("svg .quote-highlight", elem)
      .doesNotExist("leaves SVG text unwrapped");
  });

  test("highlightQuote reuses existing highlights", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML = "<p>Hello <strong>bold</strong> world</p>";

    highlightQuote(elem, "Hello bold");
    const highlights = highlightQuote(elem, "Hello bold");

    assert.strictEqual(highlights.length, 2, "returns both highlights");
    assert
      .dom(".quote-highlight .quote-highlight", elem)
      .doesNotExist("does not nest highlights");
  });

  test("highlightQuote falls back to the longest matching start of the text", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML =
      "<p>The launch party starts on <span>Oct 19, 4:00 PM</span> at the park</p>";

    const highlights = highlightQuote(
      elem,
      "The launch party starts on 2026-10-19T14:00:00Z at the park"
    );

    assert.deepEqual(
      highlights.map((highlight) => highlight.textContent),
      ["The launch party starts on"],
      "highlights the matching start"
    );
  });

  test("highlightQuote leaves the element untouched without a long enough match", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML = "<p>The <em>dog</em> barked</p>";

    assert.deepEqual(
      highlightQuote(elem, "The cat sat on the mat all day"),
      [],
      "ignores a match shorter than the minimum"
    );
    assert.deepEqual(
      highlightQuote(elem, undefined),
      [],
      "ignores a missing quote"
    );
    assert.strictEqual(
      elem.innerHTML,
      "<p>The <em>dog</em> barked</p>",
      "leaves the markup untouched"
    );
  });
});

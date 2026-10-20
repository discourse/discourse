import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { highlightQuote, quotableText } from "discourse/lib/quote";
import { fixture } from "discourse/tests/helpers/qunit-helpers";

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

  test("highlightQuote matches media and oneboxes by their source", function (assert) {
    const quote = document.createElement("div");
    quote.innerHTML =
      "<p>Look</p><p><img src='/uploads/a.png' data-base62-sha1='abc'><img src='/uploads/b.png'></p><div class='video-placeholder-container' data-video-src='/uploads/c.mp4'></div><p><a href='https://example.com'>https://example.com</a></p><p><a class='inline-onebox' href='https://example.com/page'>Page</a></p><p>done</p>";
    const elem = document.createElement("div");
    elem.innerHTML =
      "<p>Look</p><div class='lightbox-wrapper'><a class='lightbox'><img src='/optimized/a.png' data-base62-sha1='abc'><div class='meta'>a.png 10×10</div></a></div><img src='//cdn/uploads/b.png'><div class='video-container' data-video-src='/uploads/c.mp4'><video><source src='/uploads/c.mp4'><a href='/uploads/c.mp4'>/uploads/c.mp4</a></video></div><aside class='onebox' data-onebox-src='https://example.com'>Example Domain</aside><aside class='onebox' data-onebox-src='https://example.com/page'>Page</aside><p>done</p>";
    fixture().append(elem);

    const highlights = highlightQuote(elem, quotableText(quote));

    assert.deepEqual(
      highlights.map((highlight) => highlight.tagName),
      ["SPAN", "IMG", "IMG", "DIV", "ASIDE", "ASIDE", "SPAN"],
      "highlights text, images, videos and oneboxes"
    );
  });

  test("highlightQuote matches an upload across its sizes", function (assert) {
    const sha1 = "5e820b8990e256f3625c184f514507b597b52d74";
    const quote = document.createElement("div");
    quote.innerHTML = `<p><img src='/uploads/default/original/1X/${sha1}.jpeg' data-base62-sha1='du3v9AE'></p><p><img src='http://exa mple.com/a.png'></p>`;
    const elem = document.createElement("div");
    elem.innerHTML = `<p><img src='//cdn/optimized/1X/${sha1}_2_690x388.jpeg'></p><p><img src='http://exa mple.com/a.png'></p>`;
    fixture().append(elem);

    const highlights = highlightQuote(elem, quotableText(quote));

    assert.deepEqual(
      highlights.map((highlight) => highlight.tagName),
      ["IMG", "IMG"],
      "matches the optimized copy and tolerates a malformed source"
    );
  });

  test("highlightQuote highlights media inside closed details", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML =
      "<details><summary>More</summary><p><img src='/uploads/a.png'></p></details>";
    fixture().append(elem);

    const [highlight] = highlightQuote(
      elem,
      quotableText(elem.querySelector("p"))
    );

    assert.strictEqual(highlight.tagName, "IMG", "highlights the image itself");
  });

  test("highlightQuote highlights the container of hidden media", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML =
      "<p class='player'><img src='/thumb.jpg' style='display: none'><iframe></iframe></p>";
    fixture().append(elem);

    const [highlight] = highlightQuote(elem, quotableText(elem));

    assert
      .dom(highlight)
      .hasClass("player", "highlights the visible container");
  });

  test("highlightQuote ignores emoji", function (assert) {
    const elem = document.createElement("div");
    elem.innerHTML =
      "<p>Read the docs <img src='/images/emoji/link.png' class='emoji'> before asking</p>";

    const highlights = highlightQuote(elem, "Read the docs before asking");

    assert.deepEqual(
      highlights.map((highlight) => highlight.textContent),
      ["Read the docs", "before asking"],
      "matches across the emoji"
    );
  });

  test("quotableText ignores quote titles", function (assert) {
    const quote = document.createElement("div");
    quote.innerHTML =
      "<aside class='quote'><div class='title'>Someone said:</div><blockquote>Hi</blockquote></aside>";

    assert.strictEqual(quotableText(quote), "Hi", "skips the title");
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

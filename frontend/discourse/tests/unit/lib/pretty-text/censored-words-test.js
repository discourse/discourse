import { setupTest } from "ember-qunit";
import { censor, censorFn } from "pretty-text/censored-words";
import { module, test } from "qunit";

const WORD = (word, options = { case_sensitive: false }) => ({
  [`(?:\\W|^)(${word})(?=\\W|$)`]: options,
});

module("Unit | Pretty Text | Censored Words", function (hooks) {
  setupTest(hooks);

  test("censorFn returns the text unchanged without a list", function (assert) {
    assert.strictEqual(censorFn(null)("a bad word"), "a bad word");
    assert.strictEqual(censorFn([])("a bad word"), "a bad word");
  });

  test("censorFn replaces each letter of the captured word", function (assert) {
    const censorText = censorFn([WORD("bad")]);

    assert.strictEqual(
      censorText("a bad word"),
      "a &#9632;&#9632;&#9632; word",
      "keeps the surrounding text of the match"
    );
    assert.strictEqual(
      censorText("a BAD word"),
      "a &#9632;&#9632;&#9632; word",
      "matches case-insensitively by default"
    );
    assert.strictEqual(
      censorText("bad, bad"),
      "&#9632;&#9632;&#9632;, &#9632;&#9632;&#9632;",
      "replaces every occurrence"
    );
  });

  test("censorFn respects case-sensitive words", function (assert) {
    const censorText = censorFn([WORD("Bad", { case_sensitive: true })]);

    assert.strictEqual(censorText("a bad word"), "a bad word");
    assert.strictEqual(
      censorText("a Bad word"),
      "a &#9632;&#9632;&#9632; word"
    );
  });

  test("censorFn applies every word in the list", function (assert) {
    const censorText = censorFn([WORD("bad"), WORD("ugly")]);

    assert.strictEqual(
      censorText("bad and ugly"),
      "&#9632;&#9632;&#9632; and &#9632;&#9632;&#9632;&#9632;"
    );
  });

  test("censorFn uses the replacement letter", function (assert) {
    assert.strictEqual(
      censorFn([WORD("bad")], "*")("a bad word"),
      "a *** word"
    );
  });

  test("censor censors the text in one call", function (assert) {
    assert.strictEqual(censor("a bad word", [WORD("bad")], "x"), "a xxx word");
  });
});

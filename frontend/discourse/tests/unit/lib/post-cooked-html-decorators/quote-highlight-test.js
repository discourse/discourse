import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { REVEAL_EVENT } from "discourse/lib/highlight-html";
import decorateQuoteHighlight from "discourse/lib/post-cooked-html-decorators/quote-highlight";
import { QUOTE_HIGHLIGHT_ID } from "discourse/lib/quote";

module("Unit | Utility | quote-highlight decorator", function (hooks) {
  setupTest(hooks);

  test("anchors the post when the quote no longer matches", function (assert) {
    const post = document.createElement("div");
    post.className = "topic-post";
    post.innerHTML =
      "<div class='cooked'><p>Edited since it was quoted</p></div>";

    run(() =>
      decorateQuoteHighlight(post.querySelector(".cooked"), {
        quoteHighlight: { quote: "Original wording", revealed: false },
      })
    );

    assert.strictEqual(post.id, QUOTE_HIGHLIGHT_ID, "anchors the whole post");
  });

  test("anchors the first highlight and reveals it only once", function (assert) {
    const element = document.createElement("div");
    element.innerHTML = "<p>Original wording</p>";
    let reveals = 0;
    element.addEventListener(REVEAL_EVENT, () => reveals++);
    const quoteHighlight = { quote: "Original wording", revealed: false };

    run(() => decorateQuoteHighlight(element, { quoteHighlight }));
    run(() => decorateQuoteHighlight(element, { quoteHighlight }));

    assert.strictEqual(
      element.querySelector(`#${QUOTE_HIGHLIGHT_ID}`).textContent,
      "Original wording",
      "anchors the first highlight"
    );
    assert.strictEqual(reveals, 1, "reveals only on the first render");
  });
});

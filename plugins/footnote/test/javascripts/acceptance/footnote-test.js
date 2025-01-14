import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Footnote Plugin", function (needs) {
  needs.settings({
    display_footnotes_inline: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/45.json", () => {
      let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
      topic["post_stream"]["posts"][0]["cooked"] = `
        <p>Lorem ipsum dolor sit amet<sup class="footnote-ref"><a href="#footnote-17-1" id="footnote-ref-17-1">[1]</a></sup></p>
        <p class="second">Second reference should also work. <sup class="footnote-ref"><a href="#footnote-17-1" id="footnote-ref-17-0">[1]</a></sup></p>
        <hr class="footnotes-sep">
        <ol class="footnotes-list">
          <li id="footnote-17-1" class="footnote-item">
          <p>consectetur adipiscing elit <a href="#footnote-ref-17-1" class="footnote-backref">↩︎</a></p>
          </li>
        </ol>
      `;
      return helper.response(topic);
    });
  });

  test("displays the footnote on click", async function (assert) {
    await visit("/t/-/45");

    assert.dom("#footnote-tooltip", document.body).exists();

    // open
    await click(".expand-footnote");
    assert
      .dom(".footnote-tooltip-content", document.body)
      .hasText("consectetur adipiscing elit ↩︎");
    assert.dom("#footnote-tooltip", document.body).hasAttribute("data-show");

    // close by clicking outside
    await click(document.body);
    assert
      .dom("#footnote-tooltip", document.body)
      .doesNotHaveAttribute("data-show");

    // open again
    await click(".expand-footnote");
    assert
      .dom(".footnote-tooltip-content", document.body)
      .hasText("consectetur adipiscing elit ↩︎");
    assert.dom("#footnote-tooltip", document.body).hasAttribute("data-show");

    // close by clicking the button
    await click(".expand-footnote");
    assert
      .dom("#footnote-tooltip", document.body)
      .doesNotHaveAttribute("data-show");
  });

  test("clicking a second footnote with same name works", async function (assert) {
    await visit("/t/-/45");

    assert.dom("#footnote-tooltip", document.body).exists();

    await click(".second .expand-footnote");
    assert
      .dom(".footnote-tooltip-content", document.body)
      .hasText("consectetur adipiscing elit ↩︎");
    assert.dom("#footnote-tooltip", document.body).hasAttribute("data-show");
  });
});

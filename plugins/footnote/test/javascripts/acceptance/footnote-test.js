import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const TOOLTIP_SELECTOR =
  ".fk-d-tooltip__content[data-identifier='inline-footnote']";

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

    // open
    await click(".expand-footnote");

    assert.dom(TOOLTIP_SELECTOR).hasText("consectetur adipiscing elit ↩︎");

    // close by clicking outside
    await triggerEvent(".d-header", "pointerdown");
    assert.dom(TOOLTIP_SELECTOR).doesNotExist();

    // open again
    await click(".expand-footnote");
    assert.dom(TOOLTIP_SELECTOR).hasText("consectetur adipiscing elit ↩︎");
  });

  test("clicking a second footnote with same name works", async function (assert) {
    await visit("/t/-/45");

    await click(".second .expand-footnote");
    assert.dom(TOOLTIP_SELECTOR).hasText("consectetur adipiscing elit ↩︎");
  });
});

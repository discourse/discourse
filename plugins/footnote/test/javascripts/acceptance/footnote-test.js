import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Discourse Foonote Plugin", function (needs) {
  needs.user();

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

  test("displays the foonote on click", async function (assert) {
    await visit("/t/45");

    const tooltip = document.getElementById("footnote-tooltip");
    assert.ok(exists(tooltip));

    await click(".expand-footnote");
    assert.equal(
      tooltip.querySelector(".footnote-tooltip-content").textContent.trim(),
      "consectetur adipiscing elit ↩︎"
    );
  });

  test("clicking a second footnote with same name works", async function (assert) {
    await visit("/t/45");

    const tooltip = document.getElementById("footnote-tooltip");
    assert.ok(exists(tooltip));

    await click(".second .expand-footnote");

    assert.equal(
      tooltip.querySelector(".footnote-tooltip-content").textContent.trim(),
      "consectetur adipiscing elit ↩︎"
    );
  });
});

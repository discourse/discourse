import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

const ESC_KEYCODE = 27;
acceptance("Topic Entrance Modal", function () {
  test("can be closed with the esc key", async function (assert) {
    await visit("/");
    await click(".topic-list-item button.posts-map");
    const topicEntrance = query("#topic-entrance");
    assert.ok(
      !topicEntrance.classList.contains("hidden"),
      "topic entrance modal appears"
    );
    assert.equal(
      document.activeElement,
      topicEntrance.querySelector(".jump-top"),
      "the jump top button has focus when the modal is shown"
    );
    await triggerKeyEvent(topicEntrance, "keydown", ESC_KEYCODE);
    assert.ok(
      topicEntrance.classList.contains("hidden"),
      "topic entrance modal disappears after pressing esc"
    );
  });
});

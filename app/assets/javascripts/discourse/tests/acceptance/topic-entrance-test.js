import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic Entrance Modal", function () {
  test("can be closed with the esc key", async function (assert) {
    await visit("/");
    await click(".topic-list-item button.posts-map");

    assert
      .dom("#topic-entrance")
      .doesNotHaveClass("hidden", "topic entrance modal appears");
    assert
      .dom("#topic-entrance .jump-top")
      .isFocused("the jump top button has focus when the modal is shown");

    await triggerKeyEvent("#topic-entrance", "keydown", "Escape");
    assert
      .dom("#topic-entrance")
      .hasClass("hidden", "topic entrance modal disappears after pressing esc");
  });
});

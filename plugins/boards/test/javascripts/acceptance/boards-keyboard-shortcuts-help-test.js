import { triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Boards keyboard shortcuts help", function (needs) {
  needs.user();
  needs.settings({ boards_enabled: true });

  test("lists the current boards shortcuts", async function (assert) {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    assert.dom(".shortcut-category-boards h2").hasText("Boards");
    assert.dom(".shortcut-category-boards tbody tr").exists({ count: 4 });

    assert
      .dom(".shortcut-category-boards tbody")
      .includesText("Navigate boards / columns");
    assert
      .dom(".shortcut-category-boards tbody")
      .includesText("Navigate between cards");
    assert
      .dom(".shortcut-category-boards tbody")
      .includesText("Move selected card to an adjacent column");
    assert
      .dom(".shortcut-category-boards tbody")
      .includesText("Reorder selected card within a manually sorted column");
  });
});

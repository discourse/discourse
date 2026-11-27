import { click, triggerEvent, visit, waitUntil } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Directory - Mobile", function (needs) {
  needs.mobileView();

  test("Visit Page", async function (assert) {
    await visit("/u");
    assert
      .dom(".directory .directory-table__row")
      .exists("has a list of users");
  });
});

acceptance("User Directory - Mobile column reordering", function (needs) {
  needs.mobileView();
  needs.user({ admin: true });
  needs.settings({ enable_new_reordering_controls: true });

  async function swipeDown(selector) {
    const start = [{ clientX: 0, clientY: 0 }];
    const end = [{ clientX: 0, clientY: 200 }];
    await triggerEvent(selector, "touchstart", {
      touches: start,
      targetTouches: start,
      changedTouches: start,
    });
    // The swipe recognizer needs elapsed time to calculate velocity.
    const startedAt = Date.now();
    await waitUntil(() => Date.now() > startedAt);
    await triggerEvent(selector, "touchmove", {
      touches: end,
      targetTouches: end,
      changedTouches: end,
    });
    await triggerEvent(selector, "touchend", {
      touches: [],
      targetTouches: [],
      changedTouches: end,
    });
  }

  test("the reorder grip claims a swipe and the rest of the row can dismiss the drawer", async function (assert) {
    await visit("/u");
    await click(".open-edit-columns-btn");

    await swipeDown(".edit-directory-column .d-reorderable-list__handle svg");
    assert
      .dom(".edit-user-directory-columns-modal")
      .exists("the grip keeps the drawer open");

    await swipeDown(".edit-directory-column .column-name");
    assert
      .dom(".edit-user-directory-columns-modal")
      .doesNotExist("a swipe starting on the label dismisses the drawer");
  });
});

import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Notifications filter", function (needs) {
  needs.user();

  test("Notifications filter true", async (assert) => {
    await visit("/u/eviltrout/notifications");

    assert.ok(find(".large-notification").length >= 0);
  });

  test("Notifications filter read", async (assert) => {
    await visit("/u/eviltrout/notifications");

    const dropdown = selectKit(".notifications-filter");
    await dropdown.expand();
    await dropdown.selectRowByValue("read");

    assert.ok(find(".large-notification").length >= 0);
  });

  test("Notifications filter unread", async (assert) => {
    await visit("/u/eviltrout/notifications");

    const dropdown = selectKit(".notifications-filter");
    await dropdown.expand();
    await dropdown.selectRowByValue("unread");

    assert.ok(find(".large-notification").length >= 0);
  });
});

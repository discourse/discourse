import { settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Notifications filter", function (needs) {
  needs.user();

  test("Notifications filter all", async function (assert) {
    await visit("/u/eviltrout/notifications");

    assert.ok(exists(".notification.unread"));
    assert.ok(exists(".notification.read"));
  });

  test("Notifications filter read", async function (assert) {
    await visit("/u/eviltrout/notifications");

    const dropdown = selectKit(".notifications-filter");
    await dropdown.expand();
    await dropdown.selectRowByValue("unread");

    await settled();

    assert.ok(exists(".notification.read"));
  });

  test("Notifications filter unread", async function (assert) {
    await visit("/u/eviltrout/notifications");

    const dropdown = selectKit(".notifications-filter");
    await dropdown.expand();
    await dropdown.selectRowByValue("unread");

    await settled();

    assert.ok(exists(".notification.unread"));
  });
});

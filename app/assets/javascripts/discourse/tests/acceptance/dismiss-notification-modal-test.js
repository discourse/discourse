import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import pretender from "../helpers/create-pretender";

acceptance("Dismiss notification confirmation", function (needs) {
  needs.user();

  test("does not show modal when no high priority notifications", async function (assert) {
    pretender.put("/notifications/mark-read", () => {
      return [200, { "Content-Type": "application/json" }, { success: true }];
    });

    await visit("/");
    await click(".current-user");
    await click(".notifications-dismiss");
    assert.notOk(exists(".dismiss-notification-confirmation"));
  });

  test("shows confirmation modal", async function (assert) {
    updateCurrentUser({
      unread_high_priority_notifications: 2,
    });
    await visit("/");
    await click(".current-user");
    await click(".notifications-dismiss");
    assert.ok(exists(".dismiss-notification-confirmation"));

    assert.strictEqual(
      query(".dismiss-notification-confirmation-modal .modal-body").innerText,
      "You have 2 important notifications, are you sure you would like to dismiss?"
    );
  });

  test("marks unread when confirm and closes modal", async function (assert) {
    updateCurrentUser({
      unread_high_priority_notifications: 2,
    });
    await visit("/");
    await click(".current-user");
    await click(".notifications-dismiss");

    assert.strictEqual(
      query(".dismiss-notification-confirmation-modal .btn-primary").innerText,
      "Confirm"
    );
    pretender.put("/notifications/mark-read", () => {
      return [200, { "Content-Type": "application/json" }, { success: true }];
    });

    await click(".dismiss-notification-confirmation-modal .btn-primary");

    assert.notOk(exists(".dismiss-notification-confirmation"));
  });

  test("does marks unread when cancel and closes modal", async function (assert) {
    updateCurrentUser({
      unread_high_priority_notifications: 2,
    });
    await visit("/");
    await click(".current-user");
    await click(".notifications-dismiss");

    assert.strictEqual(
      query(".dismiss-notification-confirmation-modal .cancel").innerText,
      "Cancel"
    );

    await click(".dismiss-notification-confirmation-modal .cancel");

    assert.notOk(exists(".dismiss-notification-confirmation"));
  });
});

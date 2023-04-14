import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { test } from "qunit";
import pretender, { response } from "../helpers/create-pretender";

acceptance("Dismiss notification confirmation", function (needs) {
  needs.user();

  test("does not show modal when no high priority notifications", async function (assert) {
    pretender.put("/notifications/mark-read", () =>
      response({ success: true })
    );

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
      I18n.t("notifications.dismiss_confirmation.body.default", { count: 2 })
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
      I18n.t("notifications.dismiss_confirmation.dismiss")
    );
    pretender.put("/notifications/mark-read", () =>
      response({ success: true })
    );

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
      query(".dismiss-notification-confirmation-modal .btn-default").innerText,
      I18n.t("notifications.dismiss_confirmation.cancel")
    );

    await click(".dismiss-notification-confirmation-modal .btn-default");

    assert.notOk(exists(".dismiss-notification-confirmation"));
  });
});

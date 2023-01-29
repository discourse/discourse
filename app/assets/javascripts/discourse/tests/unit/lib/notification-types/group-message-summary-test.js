import { module, test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { deepMerge } from "discourse-common/lib/object";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";
import Notification from "discourse/models/notification";
import I18n from "I18n";
import { setupTest } from "ember-qunit";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.group_message_summary,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        data: {
          group_id: 321,
          group_name: "drummers",
          inbox_count: 13,
          username: "drummers.boss",
        },
      },
      overrides
    )
  );
}

module("Unit | Notification Types | group-message-summary", function (hooks) {
  setupTest(hooks);

  test("description", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "group_message_summary",
      this.siteSettings
    );
    assert.strictEqual(
      director.description,
      I18n.t("notifications.group_message_summary", {
        group_name: "drummers",
        count: 13,
      }),
      "displays the right content"
    );
  });

  test("linkHref", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "group_message_summary",
      this.siteSettings
    );
    assert.strictEqual(
      director.linkHref,
      "/u/drummers.boss/messages/group/drummers",
      "links to the group inbox in the user profile"
    );
  });
});

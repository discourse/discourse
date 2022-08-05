import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { deepMerge } from "discourse-common/lib/object";
import { createRenderDirector } from "discourse/tests/helpers/notification-items-helper";
import Notification from "discourse/models/notification";
import I18n from "I18n";

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

discourseModule(
  "Unit | Notification Items | group-message-summary",
  function () {
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
  }
);

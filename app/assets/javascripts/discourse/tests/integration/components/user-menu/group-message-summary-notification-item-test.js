import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { render } from "@ember/test-helpers";
import { deepMerge } from "discourse-common/lib/object";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import Notification from "discourse/models/notification";
import { hbs } from "ember-cli-htmlbars";
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

module(
  "Integration | Component | user-menu | group-message-summary-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::GroupMessageSummaryNotificationItem @item={{this.notification}}/>`;

    test("the notification displays the right content", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const notification = query("li");
      assert.strictEqual(
        notification.textContent.trim(),
        I18n.t("notifications.group_message_summary", {
          count: 13,
          group_name: "drummers",
        })
      );
      assert.ok(!exists("li .notification-label"));
      assert.ok(!exists("li .notification-description"));
    });
  }
);

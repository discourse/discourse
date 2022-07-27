import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
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
        notification_type: NOTIFICATION_TYPES.liked_consolidated,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        data: {
          topic_title: "this is some topic and it's irrelevant",
          original_post_id: 3294,
          original_post_type: 1,
          original_username: "liker439",
          display_username: "liker439",
          username: "liker439",
          count: 44,
        },
      },
      overrides
    )
  );
}

module(
  "Integration | Component | user-menu | liked-consolidated-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::LikedConsolidatedNotificationItem @item={{this.notification}}/>`;

    test("the notification links to the likes received notifications page of the user", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const link = query("li a");
      assert.ok(
        link.href.endsWith(
          "/u/eviltrout/notifications/likes-received?acting_username=liker439"
        )
      );
    });

    test("the notification label displays the user who liked", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const label = query("li .notification-label");
      assert.strictEqual(label.textContent.trim(), "liker439");
    });

    test("the notification description displays the number of likes", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const description = query("li .notification-description");
      assert.strictEqual(
        description.textContent.trim(),
        I18n.t("notifications.liked_consolidated_description", { count: 44 })
      );
    });
  }
);

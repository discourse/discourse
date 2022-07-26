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
        notification_type: NOTIFICATION_TYPES.liked,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        data: {
          topic_title: "this is title before it becomes fancy <a>!",
          username: "osama",
          display_username: "osama",
          username2: "shrek",
          count: 2,
        },
      },
      overrides
    )
  );
}

module(
  "Integration | Component | user-menu | liked-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::LikedNotificationItem @item={{this.notification}}/>`;

    test("when the likes count is 2", async function (assert) {
      this.set("notification", getNotification({ data: { count: 2 } }));
      await render(template);

      const label = query("li .notification-label");
      const description = query("li .notification-description");
      assert.strictEqual(
        label.textContent.trim(),
        "osama, shrek",
        "the label displays both usernames comma-concatenated"
      );
      assert.ok(
        label.classList.contains("double-user"),
        "label has double-user class"
      );
      assert.strictEqual(
        description.textContent.trim(),
        "This is fancy title <a>!",
        "the description displays the topic title"
      );
    });

    test("when the likes count is more than 2", async function (assert) {
      this.set("notification", getNotification({ data: { count: 3 } }));
      await render(template);

      const label = query("li .notification-label");
      const description = query("li .notification-description");
      assert.strictEqual(
        label.textContent.trim(),
        I18n.t("notifications.liked_by_multiple_users", {
          username: "osama",
          username2: "shrek",
          count: 1,
        }),
        "the label displays the first 2 usernames comma-concatenated with the count of remaining users"
      );
      assert.ok(
        label.classList.contains("multi-user"),
        "label has multi-user class"
      );
      assert.strictEqual(
        description.textContent.trim(),
        "This is fancy title <a>!",
        "the description displays the topic title"
      );
    });

    test("when the likes count is 1", async function (assert) {
      this.set(
        "notification",
        getNotification({ data: { count: 1, username2: null } })
      );
      await render(template);

      const label = query("li .notification-label");
      const description = query("li .notification-description");
      assert.strictEqual(
        label.textContent.trim(),
        "osama",
        "the label displays the username"
      );
      assert.strictEqual(
        description.textContent.trim(),
        "This is fancy title <a>!",
        "the description displays the topic title"
      );
    });
  }
);

import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { deepMerge } from "discourse-common/lib/object";
import { render } from "@ember/test-helpers";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import Notification from "discourse/models/notification";
import { hbs } from "ember-cli-htmlbars";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.group_mentioned,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        data: {
          topic_title: "this is title before it becomes fancy <a>!",
          original_post_id: 112,
          original_post_type: 1,
          original_username: "kolary",
          display_username: "osama",
          group_id: 333,
          group_name: "hikers",
        },
      },
      overrides
    )
  );
}

module(
  "Integration | Component | user-menu | group-mentioned-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::GroupMentionedNotificationItem @item={{this.notification}}/>`;

    test("notification label displays the user who mentioned and the mentioned group", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const label = query("li .notification-label");
      assert.strictEqual(label.textContent.trim(), "osama @hikers");
      assert.ok(
        label.classList.contains("mention-group"),
        "label has mention-group class"
      );
      assert.ok(label.classList.contains("notify"), "label has notify class");
    });

    test("notification description displays the topic title", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const description = query("li .notification-description");
      assert.strictEqual(
        description.textContent.trim(),
        "This is fancy title <a>!"
      );
    });
  }
);

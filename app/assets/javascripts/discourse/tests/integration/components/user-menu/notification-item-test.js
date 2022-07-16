import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { render, settled } from "@ember/test-helpers";
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
        notification_type: NOTIFICATION_TYPES.mentioned,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        data: {
          topic_title: "this is title before it becomes fancy <a>!",
          display_username: "osama",
          original_post_id: 1,
          original_post_type: 1,
          original_username: "velesin",
        },
      },
      overrides
    )
  );
}

module(
  "Integration | Component | user-menu | notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::NotificationItem @item={{this.notification}}/>`;

    test("pushes `read` to the classList if the notification is read", async function (assert) {
      this.set("notification", getNotification());
      this.notification.read = false;
      await render(template);
      assert.ok(!exists("li.read"));
      assert.ok(exists("li"));

      this.notification.read = true;
      await settled();

      assert.ok(
        exists("li.read"),
        "the item re-renders when the read property is updated"
      );
    });

    test("pushes the notification type name to the classList", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      let item = query("li");
      assert.strictEqual(item.className, "mentioned");

      this.set(
        "notification",
        getNotification({
          notification_type: NOTIFICATION_TYPES.private_message,
        })
      );
      await settled();

      assert.ok(
        exists("li.private-message"),
        "replaces underscores in type name with dashes"
      );
    });

    test("pushes is-warning to the classList if the notification originates from a warning PM", async function (assert) {
      this.set("notification", getNotification({ is_warning: true }));
      await render(template);
      assert.ok(exists("li.is-warning"));
    });

    test("doesn't push is-warning to the classList if the notification doesn't originate from a warning PM", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      assert.ok(!exists("li.is-warning"));
      assert.ok(exists("li"));
    });

    test("the item's href links to the topic that the notification originates from", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const link = query("li a");
      assert.ok(link.href.endsWith("/t/this-is-fancy-title/449/113"));
    });

    test("the item's href links to the group messages if the notification is for a group messages", async function (assert) {
      this.set(
        "notification",
        getNotification({
          topic_id: null,
          post_number: null,
          slug: null,
          data: {
            group_id: 33,
            group_name: "grouperss",
            username: "ossaama",
          },
        })
      );
      await render(template);
      const link = query("li a");
      assert.ok(link.href.endsWith("/u/ossaama/messages/grouperss"));
    });

    test("the item's link has a title for accessibility", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const link = query("li a");
      assert.strictEqual(link.title, I18n.t("notifications.titles.mentioned"));
    });

    test("has elements for label and description", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const label = query("li a .notification-label");
      const description = query("li a .notification-description");

      assert.strictEqual(
        label.textContent.trim(),
        "osama",
        "the label's content is the username by default"
      );

      assert.strictEqual(
        description.textContent.trim(),
        "This is fancy title <a>!",
        "the description defaults to the fancy_title"
      );
    });

    test("the description falls back to topic_title from data if fancy_title is absent", async function (assert) {
      this.set(
        "notification",
        getNotification({
          fancy_title: null,
        })
      );
      await render(template);
      const description = query("li a .notification-description");

      assert.strictEqual(
        description.textContent.trim(),
        "this is title before it becomes fancy <a>!",
        "topic_title from data is rendered safely"
      );
    });

    test("fancy_title is emoji-unescaped", async function (assert) {
      this.set(
        "notification",
        getNotification({
          fancy_title: "title with emoji :phone:",
        })
      );
      await render(template);
      assert.ok(
        exists("li a .notification-description img.emoji"),
        "emojis are unescaped when fancy_title is used for description"
      );
    });

    test("topic_title from data is not emoji-unescaped", async function (assert) {
      this.set(
        "notification",
        getNotification({
          fancy_title: null,
          data: {
            topic_title: "unsafe title with unescaped emoji :phone:",
          },
        })
      );
      await render(template);
      const description = query("li a .notification-description");

      assert.strictEqual(
        description.textContent.trim(),
        "unsafe title with unescaped emoji :phone:",
        "emojis aren't unescaped when topic title is not safe"
      );
      assert.ok(!query("img"), "no <img> exists");
    });
  }
);

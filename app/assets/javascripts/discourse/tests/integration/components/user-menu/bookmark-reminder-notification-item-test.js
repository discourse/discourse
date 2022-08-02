import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { deepMerge } from "discourse-common/lib/object";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { render } from "@ember/test-helpers";
import Notification from "discourse/models/notification";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.bookmark_reminder,
        read: false,
        high_priority: true,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        data: {
          title: "this is unsafe bookmark title <a>!",
          display_username: "osama",
          bookmark_name: null,
          bookmarkable_url: "/t/sometopic/3232",
        },
      },
      overrides
    )
  );
}

module(
  "Integration | Component | user-menu | bookmark-reminder-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::BookmarkReminderNotificationItem @item={{this.notification}}/>`;

    test("when the bookmark has a name", async function (assert) {
      this.set(
        "notification",
        getNotification({ data: { bookmark_name: "MY BOOKMARK" } })
      );
      await render(template);
      const link = query("li a");
      assert.strictEqual(
        link.title,
        I18n.t("notifications.titles.bookmark_reminder_with_name", {
          name: "MY BOOKMARK",
        }),
        "the notification has a title that includes the bookmark name"
      );
    });

    test("when the bookmark doesn't have a name", async function (assert) {
      this.set(
        "notification",
        getNotification({ data: { bookmark_name: null } })
      );
      await render(template);
      const link = query("li a");
      assert.strictEqual(
        link.title,
        I18n.t("notifications.titles.bookmark_reminder"),
        "the notification has a generic title"
      );
    });

    test("when the bookmark reminder doesn't originate from a topic and has a title", async function (assert) {
      this.set(
        "notification",
        getNotification({
          post_number: null,
          topic_id: null,
          fancy_title: null,
          data: {
            title: "this is unsafe bookmark title <a>!",
            bookmarkable_url: "/chat/channel/33",
          },
        })
      );
      await render(template);
      const description = query("li .notification-description");
      assert.strictEqual(
        description.textContent.trim(),
        "this is unsafe bookmark title <a>!",
        "the title is rendered safely as description"
      );
    });

    test("when the bookmark reminder originates from a topic", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const description = query("li .notification-description");
      assert.strictEqual(
        description.textContent.trim(),
        "This is fancy title <a>!",
        "fancy_title is safe and rendered correctly"
      );
    });
  }
);

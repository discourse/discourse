import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import NotificationFixtures from "discourse/tests/fixtures/notification-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "discourse-i18n";

function getNotificationsData() {
  return cloneJSON(NotificationFixtures["/notifications"].notifications);
}

module(
  "Integration | Component | user-menu | notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    let notificationsData = getNotificationsData();
    let queryParams = null;
    let markRead = false;
    let notificationsFetches = 0;
    hooks.beforeEach(() => {
      pretender.get("/notifications", (request) => {
        queryParams = request.queryParams;
        notificationsFetches++;
        return response({ notifications: notificationsData });
      });

      pretender.put("/notifications/mark-read", () => {
        markRead = true;
        return response({ success: true });
      });
    });

    hooks.afterEach(() => {
      notificationsData = getNotificationsData();
      queryParams = null;
      markRead = false;
      notificationsFetches = 0;
    });

    const template = hbs`<UserMenu::NotificationsList/>`;

    test("empty state when there are no notifications", async function (assert) {
      notificationsData.clear();
      await render(template);
      assert.dom(".empty-state .empty-state-title").exists();
      assert.dom(".empty-state .empty-state-body").exists();
    });

    test("doesn't set filter_by_types in the params of the request that fetches the notifications", async function (assert) {
      await render(template);
      assert.strictEqual(
        queryParams.filter_by_types,
        undefined,
        "filter_by_types param is absent"
      );
    });

    test("doesn't request the full notifications list in silent mode", async function (assert) {
      await render(template);
      assert.strictEqual(queryParams.silent, undefined);
    });

    test("show all button for all notifications page", async function (assert) {
      await render(template);
      assert
        .dom(".panel-body-bottom .btn.show-all")
        .hasAttribute(
          "title",
          I18n.t("user_menu.view_all_notifications"),
          "has the correct title"
        );
    });

    test("has a dismiss button if some notification types have unread notifications", async function (assert) {
      this.currentUser.set("grouped_unread_notifications", {
        [NOTIFICATION_TYPES.mentioned]: 1,
      });
      await render(template);
      const dismissButton = query(
        ".panel-body-bottom .btn.notifications-dismiss"
      );
      assert.strictEqual(
        dismissButton.textContent.trim(),
        I18n.t("user.dismiss"),
        "dismiss button has a label"
      );
      assert
        .dom(".panel-body-bottom .btn.notifications-dismiss")
        .hasAttribute(
          "title",
          I18n.t("user.dismiss_notifications_tooltip"),
          "dismiss button has title attribute"
        );
    });

    test("doesn't have a dismiss button if all notifications are read", async function (assert) {
      notificationsData.forEach((notification) => {
        notification.read = true;
      });
      await render(template);
      assert
        .dom(".panel-body-bottom .btn.notifications-dismiss")
        .doesNotExist();
    });

    test("dismiss button makes a request to the server and then refreshes the notifications list", async function (assert) {
      await render(template);
      this.currentUser.set("grouped_unread_notifications", {
        [NOTIFICATION_TYPES.mentioned]: 1,
      });
      assert.strictEqual(notificationsFetches, 1);
      await click(".panel-body-bottom .btn.notifications-dismiss");
      assert.ok(markRead, "request to the server is made");
      assert.strictEqual(
        notificationsFetches,
        2,
        "notifications list is refreshed"
      );
      assert
        .dom(".panel-body-bottom .btn.notifications-dismiss")
        .doesNotExist("dismiss button is not shown");
    });

    test("all notifications tab shows pending reviewables and sorts them with unread notifications based on their creation date", async function (assert) {
      pretender.get("/notifications", () => {
        return response({
          notifications: [
            {
              id: 6,
              user_id: 1,
              notification_type: NOTIFICATION_TYPES.mentioned,
              read: false,
              high_priority: false,
              created_at: "2021-11-25T19:31:13.241Z",
              post_number: 6,
              topic_id: 10,
              fancy_title: "Unread notification #01",
              slug: "unread-notification-01",
              data: {
                topic_title: "Unread notification #01",
                original_post_id: 20,
                original_post_type: 1,
                original_username: "discobot",
                revision_number: null,
                display_username: "discobot",
              },
            },
            {
              id: 13,
              user_id: 1,
              notification_type: NOTIFICATION_TYPES.replied,
              read: false,
              high_priority: false,
              created_at: "2021-08-25T19:31:13.241Z",
              post_number: 6,
              topic_id: 10,
              fancy_title: "Unread notification #02",
              slug: "unread-notification-02",
              data: {
                topic_title: "Unread notification #02",
                original_post_id: 20,
                original_post_type: 1,
                original_username: "discobot",
                revision_number: null,
                display_username: "discobot",
              },
            },
            {
              id: 81,
              user_id: 1,
              notification_type: NOTIFICATION_TYPES.mentioned,
              read: true,
              high_priority: false,
              created_at: "2022-10-25T19:31:13.241Z",
              post_number: 6,
              topic_id: 10,
              fancy_title: "Read notification #01",
              slug: "read-notification-01",
              data: {
                topic_title: "Read notification #01",
                original_post_id: 20,
                original_post_type: 1,
                original_username: "discobot",
                revision_number: null,
                display_username: "discobot",
              },
            },
          ],
          pending_reviewables: [
            {
              flagger_username: "sayo2",
              id: 83,
              pending: true,
              topic_fancy_title: "anything hello world 0011",
              type: "ReviewableQueuedPost",
              created_at: "2022-09-25T19:31:13.241Z",
            },
            {
              flagger_username: "sayo2",
              id: 78,
              pending: true,
              topic_fancy_title: "anything hello world 0033",
              type: "ReviewableQueuedPost",
              created_at: "2021-06-25T19:31:13.241Z",
            },
          ],
        });
      });
      await render(template);
      const items = queryAll("ul li");
      assert.ok(
        items[0].textContent.includes("hello world 0011"),
        "the first pending reviewable is displayed 1st because it's most recent among pending reviewables and unread notifications"
      );
      assert.ok(
        items[1].textContent.includes("Unread notification #01"),
        "the first unread notification is displayed 2nd because it's the 2nd most recent among pending reviewables and unread notifications"
      );
      assert.ok(
        items[2].textContent.includes("Unread notification #02"),
        "the second unread notification is displayed 3rd because it's the 3rd most recent among pending reviewables and unread notifications"
      );
      assert.ok(
        items[3].textContent.includes("hello world 0033"),
        "the second pending reviewable is displayed 4th because it's the 4th most recent among pending reviewables and unread notifications"
      );
      assert.ok(
        items[4].textContent.includes("Read notification #01"),
        "read notifications come after the pending reviewables and unread notifications"
      );
    });
  }
);

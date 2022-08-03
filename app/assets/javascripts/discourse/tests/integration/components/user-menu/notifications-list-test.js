import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { click, render } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import NotificationFixtures from "discourse/tests/fixtures/notification-fixtures";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import I18n from "I18n";

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
      assert.ok(exists(".empty-state .empty-state-title"));
      assert.ok(exists(".empty-state .empty-state-body"));
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

    test("displays a show all button that takes to the notifications page of the current user", async function (assert) {
      await render(template);
      const showAllBtn = query(".panel-body-bottom .btn.show-all");
      assert.ok(
        showAllBtn.href.endsWith("/u/eviltrout/notifications"),
        "it takes you to the notifications page"
      );
      assert.strictEqual(
        showAllBtn.getAttribute("title"),
        I18n.t("user_menu.view_all_notifications"),
        "title attribute is present"
      );
    });

    test("has a dismiss button if some notifications are not read", async function (assert) {
      notificationsData.forEach((notification) => {
        notification.read = true;
      });
      notificationsData[0].read = false;
      await render(template);
      const dismissButton = query(
        ".panel-body-bottom .btn.notifications-dismiss"
      );
      assert.strictEqual(
        dismissButton.textContent.trim(),
        I18n.t("user.dismiss"),
        "dismiss button has a label"
      );
      assert.strictEqual(
        dismissButton.getAttribute("title"),
        I18n.t("user.dismiss_notifications_tooltip"),
        "dismiss button has title attribute"
      );
    });

    test("doesn't have a dismiss button if all notifications are read", async function (assert) {
      notificationsData.forEach((notification) => {
        notification.read = true;
      });
      await render(template);
      assert.ok(!exists(".panel-body-bottom .btn.notifications-dismiss"));
    });

    test("dismiss button makes a request to the server and then refreshes the notifications list", async function (assert) {
      await render(template);
      notificationsData = getNotificationsData();
      notificationsData.forEach((notification) => {
        notification.read = true;
      });
      assert.strictEqual(notificationsFetches, 1);
      await click(".panel-body-bottom .btn.notifications-dismiss");
      assert.ok(markRead, "request to the server is made");
      assert.strictEqual(
        notificationsFetches,
        2,
        "notifications list is refreshed"
      );
      assert.ok(
        !exists(".panel-body-bottom .btn.notifications-dismiss"),
        "dismiss button is not shown"
      );
    });
  }
);

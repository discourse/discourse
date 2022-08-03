import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse-common/lib/object";
import TopicFixtures from "discourse/tests/fixtures/topic";
import I18n from "I18n";

acceptance("User menu", function (needs) {
  needs.user({ redesigned_user_menu_enabled: true });
  let requestHeaders = {};

  needs.pretender((server, helper) => {
    server.get("/t/1234.json", (request) => {
      const json = cloneJSON(TopicFixtures["/t/130.json"]);
      json.id = 1234;
      json.post_stream.posts.forEach((post) => {
        post.topic_id = 1234;
      });
      requestHeaders = request.requestHeaders;
      return helper.response(json);
    });
  });

  needs.hooks.afterEach(() => {
    requestHeaders = {};
  });

  test("clicking on an unread notification", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user");
    await click(".user-menu ul li.replied a");

    assert.strictEqual(
      requestHeaders["Discourse-Clear-Notifications"],
      123, // id is from the fixtures in fixtures/notification-fixtures.js
      "the Discourse-Clear-Notifications request header is set to the notification id in the next ajax request"
    );
  });
});

acceptance("User menu - Dismiss button", function (needs) {
  needs.user({
    redesigned_user_menu_enabled: true,
    unread_high_priority_notifications: 10,
  });

  let markRead = false;

  needs.pretender((server, helper) => {
    server.put("/notifications/mark-read", () => {
      markRead = true;
      return helper.response({ success: true });
    });
  });

  needs.hooks.afterEach(() => {
    markRead = false;
  });

  test("shows confirmation modal for the all-notifications list", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user");

    await click(".user-menu .notifications-dismiss");
    assert.strictEqual(
      query(".dismiss-notification-confirmation").textContent.trim(),
      I18n.t("notifications.dismiss_confirmation.body", { count: 10 }),
      "confirmation modal is shown when there are unread high pri notifications"
    );
    assert.notOk(markRead, "mark-read request isn't sent");

    await click(".modal-footer .btn-default"); // click cancel on the dismiss modal

    updateCurrentUser({ unread_high_priority_notifications: 0 });
    await click(".user-menu .notifications-dismiss");
    assert.ok(
      markRead,
      "mark-read request is sent without a confirmation modal when there are no unread high pri notifications"
    );
  });

  test("doesn't show confirmation modal for the likes notifications panel/list", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user");

    await click("#user-menu-button-likes");
    await click(".user-menu .notifications-dismiss");
    assert.ok(
      markRead,
      "mark-read request is sent without a confirmation modal"
    );
  });
});

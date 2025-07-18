/* eslint-disable qunit/no-loose-assertions */
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const USER_MENU_ASSIGN_RESPONSE = {
  notifications: [
    {
      id: 1716,
      user_id: 1,
      notification_type: 34,
      read: false,
      high_priority: true,
      created_at: "2022-08-11T21:32:32.404Z",
      post_number: 1,
      topic_id: 227,
      fancy_title: "Test poll topic please bear with me :heart:",
      slug: "test-poll-topic-please-bear-with-me",
      data: {
        message: "discourse_assign.assign_notification",
        display_username: "tony",
        topic_title: "Test poll topic please bear with me :heart:",
        assignment_id: 2,
      },
    },
    {
      id: 1717,
      user_id: 1,
      notification_type: 34,
      read: true,
      high_priority: true,
      created_at: "2022-08-11T21:32:32.404Z",
      post_number: 1,
      topic_id: 228,
      fancy_title: "Test poll topic please bear with me 2 :ok_hand:",
      slug: "test-poll-topic-please-bear-with-me-2",
      data: {
        message: "discourse_assign.assign_group_notification",
        display_username: "Team",
        topic_title: "Test poll topic please bear with me 2 :ok_hand:",
        assignment_id: 3,
      },
    },
  ],
};

acceptance(
  "Discourse Assign | user menu | user cannot assign",
  function (needs) {
    needs.user({
      can_assign: false,
    });
    needs.settings({
      assign_enabled: true,
    });

    test("the assigns tab is not shown", async function (assert) {
      await visit("/");
      await click(".d-header-icons .current-user button");
      assert.dom("#user-menu-button-assign-list").doesNotExist();
    });
  }
);

acceptance(
  "Discourse Assign | user menu | assign_enabled setting is disabled",
  function (needs) {
    needs.user({
      can_assign: false,
    });
    needs.settings({
      assign_enabled: false,
    });

    test("the assigns tab is not shown", async function (assert) {
      await visit("/");
      await click(".d-header-icons .current-user button");
      assert.dom("#user-menu-button-assign-list").doesNotExist();
    });
  }
);

acceptance("Discourse Assign | user menu", function (needs) {
  needs.user({
    can_assign: true,
    grouped_unread_notifications: {
      34: 173, // assigned notification type
    },
  });

  needs.settings({
    assign_enabled: true,
  });

  let forceEmptyState = false;
  let markRead = false;
  let requestBody;

  needs.pretender((server, helper) => {
    server.get("/notifications", () => {
      if (forceEmptyState) {
        return helper.response({ notifications: [] });
      } else {
        return helper.response(USER_MENU_ASSIGN_RESPONSE);
      }
    });

    server.put("/notifications/mark-read", (request) => {
      requestBody = request.requestBody;
      markRead = true;
      return helper.response({ success: true });
    });

    server.get("/topics/messages-assigned/eviltrout.json", () => {
      return helper.response({
        users: [],
        topic_list: {
          topics: [],
        },
      });
    });
  });

  needs.hooks.afterEach(() => {
    forceEmptyState = false;
    markRead = false;
    requestBody = null;
  });

  test("assigns tab", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user button");
    assert.dom("#user-menu-button-assign-list").exists("assigns tab exists");
    assert
      .dom("#user-menu-button-assign-list .d-icon-user-plus")
      .exists("assigns tab has the user-plus icon");
    assert
      .dom("#user-menu-button-assign-list .badge-notification")
      .hasText("173", "assigns tab has a count badge");

    updateCurrentUser({
      grouped_unread_notifications: {},
    });

    assert
      .dom("#user-menu-button-assign-list .badge-notification")
      .doesNotExist("badge count disappears when it goes to zero");
    assert
      .dom("#user-menu-button-assign-list")
      .exists("assigns tab still exists");
  });

  test("clicking on the assign tab when it's already selected navigates to the user's assignments page", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user button");
    await click("#user-menu-button-assign-list");
    await click("#user-menu-button-assign-list");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/activity/assigned",
      "user is navigated to their assignments page"
    );
  });

  test("displays unread assign notifications on top and fills the remaining space with read assigns", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user button");
    await click("#user-menu-button-assign-list");

    const notifications = queryAll(
      "#quick-access-assign-list .notification.unread"
    );
    assert.strictEqual(
      notifications.length,
      1,
      "there is one unread notification"
    );
    assert.true(
      notifications[0].classList.contains("unread"),
      "the notification is unread"
    );
    assert.true(
      notifications[0].classList.contains("assigned"),
      "the notification is of type assigned"
    );

    const assigns = queryAll("#quick-access-assign-list .assigned");
    assert.strictEqual(assigns.length, 2, "there are 2 assigns");

    const userAssign = assigns[0];
    const groupAssign = assigns[1];
    assert.ok(
      userAssign.querySelector(".d-icon-user-plus"),
      "user assign has the right icon"
    );
    assert.ok(
      groupAssign.querySelector(".d-icon-group-plus"),
      "group assign has the right icon"
    );

    assert.true(
      userAssign
        .querySelector("a")
        .href.endsWith("/t/test-poll-topic-please-bear-with-me/227"),
      "user assign links to the assigned topic"
    );
    assert.true(
      groupAssign
        .querySelector("a")
        .href.endsWith("/t/test-poll-topic-please-bear-with-me-2/228"),
      "group assign links to the assigned topic"
    );

    assert.strictEqual(
      userAssign.textContent.trim(),
      "Test poll topic please bear with me",
      "user assign contains the topic title"
    );
    assert.ok(
      userAssign.querySelector(".item-description img.emoji"),
      "emojis are rendered in user assign"
    );

    assert.strictEqual(
      groupAssign.textContent.trim().replaceAll(/\s+/g, " "),
      "Team Test poll topic please bear with me 2",
      "group assign contains the topic title"
    );
    assert.ok(
      groupAssign.querySelector(".item-description img.emoji"),
      "emojis are rendered in group assign"
    );

    assert.strictEqual(
      userAssign.querySelector("a").title,
      i18n("user.assigned_to_you.topic"),
      "user assign has the right title"
    );
    assert.strictEqual(
      groupAssign.querySelector("a").title,
      i18n("user.assigned_to_group.topic", { group_name: "Team" }),
      "group assign has the right title"
    );
  });

  test("dismiss button", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user button");
    await click("#user-menu-button-assign-list");

    assert
      .dom("#user-menu-button-assign-list .badge-notification")
      .exists("badge count is visible before dismissing");

    await click(".notifications-dismiss");
    assert.false(markRead, "mark-read request isn't sent");
    assert.strictEqual(
      query(
        ".dismiss-notification-confirmation .d-modal__body"
      ).textContent.trim(),
      i18n("notifications.dismiss_confirmation.body.assigns", { count: 173 }),
      "dismiss confirmation modal is shown"
    );

    await click(".d-modal__footer .btn-primary");
    assert.true(markRead, "mark-read request is sent");
    assert.dom(".notifications-dismiss").doesNotExist("dismiss button is gone");
    assert
      .dom("#user-menu-button-assign-list .badge-notification")
      .doesNotExist("badge count is gone after dismissing");
    assert.strictEqual(
      requestBody,
      "dismiss_types=assigned",
      "mark-read request is sent with the right params"
    );
  });

  test("empty state", async function (assert) {
    forceEmptyState = true;
    await visit("/");
    await click(".d-header-icons .current-user button");
    await click("#user-menu-button-assign-list");

    assert
      .dom(".empty-state-title")
      .hasText(
        i18n("user.no_assignments_title"),
        "empty state title is rendered"
      );
    assert.dom(".empty-state-body").exists("empty state body exists");
    assert
      .dom(".empty-state-body .d-icon-user-plus")
      .exists("empty state body has user-plus icon");
    assert.true(
      query(".empty-state-body a").href.endsWith(
        "/my/preferences/notifications"
      ),
      "empty state body has user-plus icon"
    );
  });

  test("renders the confirmation modal when dismiss assign notifications", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user button");
    await click("#user-menu-button-assign-list");
    await click(".notifications-dismiss");
    assert.false(markRead, "a request to the server is not made");
    assert
      .dom(".dismiss-notification-confirmation .d-modal__body")
      .exists("the dismiss notification confirmation modal is present");
  });
});

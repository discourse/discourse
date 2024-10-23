import { click, render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { query, queryAll } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | user-menu", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`<UserMenu::Menu/>`;

  test("default tab is all notifications", async function (assert) {
    await render(template);
    const activeTab = query(".top-tabs.tabs-list .btn.active");
    assert.strictEqual(activeTab.id, "user-menu-button-all-notifications");
    const notifications = queryAll("#quick-access-all-notifications ul li");
    assert.ok(notifications[0].classList.contains("edited"));
    assert.ok(notifications[1].classList.contains("replied"));
    assert.ok(notifications[2].classList.contains("liked-consolidated"));
  });

  test("active tab has a11y attributes that indicate it's active", async function (assert) {
    await render(template);
    const activeTab = query(".top-tabs.tabs-list .btn.active");
    assert.strictEqual(activeTab.getAttribute("tabindex"), "0");
    assert.strictEqual(activeTab.getAttribute("aria-selected"), "true");
  });

  test("inactive tab has a11y attributes that indicate it's inactive", async function (assert) {
    await render(template);
    const inactiveTab = query(".top-tabs.tabs-list .btn:not(.active)");
    assert.strictEqual(inactiveTab.getAttribute("tabindex"), "-1");
    assert.strictEqual(inactiveTab.getAttribute("aria-selected"), "false");
  });

  test("the menu has a group of tabs at the top", async function (assert) {
    this.currentUser.set("can_send_private_messages", true);
    await render(template);
    const tabs = queryAll(".top-tabs.tabs-list .btn");
    assert.strictEqual(tabs.length, 6);
    ["all-notifications", "replies", "likes", "messages", "bookmarks"].forEach(
      (tab, index) => {
        assert.strictEqual(tabs[index].id, `user-menu-button-${tab}`);
        assert.strictEqual(tabs[index].dataset.tabNumber, index.toString());
        assert.strictEqual(
          tabs[index].getAttribute("aria-controls"),
          `quick-access-${tab}`
        );
      }
    );
  });

  test("the menu has a group of tabs at the bottom", async function (assert) {
    this.currentUser.set("can_send_private_messages", true);
    await render(template);
    const tabs = queryAll(".bottom-tabs.tabs-list .btn");
    assert.strictEqual(tabs.length, 1);
    const profileTab = tabs[0];
    assert.strictEqual(profileTab.id, "user-menu-button-profile");
    assert.strictEqual(profileTab.dataset.tabNumber, "6");
    assert.strictEqual(profileTab.getAttribute("tabindex"), "-1");
  });

  test("likes tab is hidden if current user's like notifications frequency is 'never'", async function (assert) {
    this.currentUser.set("user_option.likes_notifications_disabled", true);
    this.currentUser.set("can_send_private_messages", true);
    await render(template);
    assert.dom("#user-menu-button-likes").doesNotExist();

    const tabs = Array.from(queryAll(".tabs-list .btn")); // top and bottom tabs
    assert.strictEqual(tabs.length, 6);

    assert.deepEqual(
      tabs.map((t) => t.dataset.tabNumber),
      ["0", "1", "2", "3", "4", "5"],
      "data-tab-number of the tabs has no gaps when the likes tab is hidden"
    );
  });

  test("reviewables tab is shown if current user can review and there are pending reviewables", async function (assert) {
    this.currentUser.set("can_review", true);
    this.currentUser.set("reviewable_count", 1);
    this.currentUser.set("can_send_private_messages", true);
    await render(template);
    const tab = query("#user-menu-button-review-queue");
    assert.strictEqual(tab.dataset.tabNumber, "5");

    const tabs = Array.from(queryAll(".tabs-list .btn")); // top and bottom tabs
    assert.strictEqual(tabs.length, 8);

    assert.deepEqual(
      tabs.map((t) => t.dataset.tabNumber),
      ["0", "1", "2", "3", "4", "5", "6", "7"],
      "data-tab-number of the tabs has no gaps when the reviewables tab is show"
    );
  });

  test("reviewables tab is not shown if current user can review but there are no pending reviewables", async function (assert) {
    this.currentUser.set("can_review", true);
    this.currentUser.set("reviewable_count", 0);
    await render(template);
    assert.dom("#user-menu-button-review-queue").doesNotExist();
  });

  test("messages tab isn't shown if current user does not have can_send_private_messages permission", async function (assert) {
    this.currentUser.set("moderator", false);
    this.currentUser.set("admin", false);
    this.currentUser.set("groups", []);
    this.currentUser.set("can_send_private_messages", false);

    await render(template);

    assert.dom("#user-menu-button-messages").doesNotExist();

    const tabs = Array.from(queryAll(".tabs-list .btn")); // top and bottom tabs
    assert.strictEqual(tabs.length, 6);

    assert.deepEqual(
      tabs.map((t) => t.dataset.tabNumber),
      ["0", "1", "2", "3", "4", "5"],
      "data-tab-number of the tabs has no gaps when the messages tab is hidden"
    );
  });

  test("messages tab is shown if user has can_send_private_messages permission", async function (assert) {
    this.currentUser.set("moderator", true);
    this.currentUser.set("admin", false);
    this.currentUser.set("groups", []);
    this.currentUser.set("can_send_private_messages", true);

    await render(template);

    assert.dom("#user-menu-button-messages").exists();
  });

  test("reviewables count is shown on the reviewables tab", async function (assert) {
    this.currentUser.set("can_review", true);
    this.currentUser.set("reviewable_count", 4);
    await render(template);
    const countBadge = query(
      "#user-menu-button-review-queue .badge-notification"
    );
    assert.strictEqual(countBadge.textContent, "4");

    this.currentUser.set("reviewable_count", 0);
    await settled();

    assert
      .dom("#user-menu-button-review-queue .badge-notification")
      .doesNotExist();
  });

  test("changing tabs", async function (assert) {
    this.currentUser.set("can_review", true);
    this.currentUser.set("reviewable_count", 1);
    await render(template);
    let queryParams;
    pretender.get("/notifications", (request) => {
      queryParams = request.queryParams;
      let data;
      if (queryParams.filter_by_types === "liked,liked_consolidated,reaction") {
        data = [
          {
            id: 60,
            user_id: 1,
            notification_type: NOTIFICATION_TYPES.liked,
            read: true,
            high_priority: false,
            created_at: "2021-11-25T19:31:13.241Z",
            post_number: 6,
            topic_id: 10,
            fancy_title: "Greetings!",
            slug: "greetings",
            data: {
              topic_title: "Greetings!",
              original_post_id: 20,
              original_post_type: 1,
              original_username: "discobot",
              revision_number: null,
              display_username: "discobot",
            },
          },
          {
            id: 63,
            user_id: 1,
            notification_type: NOTIFICATION_TYPES.liked,
            read: true,
            high_priority: false,
            created_at: "2021-11-25T19:31:13.241Z",
            post_number: 6,
            topic_id: 10,
            fancy_title: "Greetings!",
            slug: "greetings",
            data: {
              topic_title: "Greetings!",
              original_post_id: 20,
              original_post_type: 1,
              original_username: "discobot",
              revision_number: null,
              display_username: "discobot",
            },
          },
          {
            id: 20,
            user_id: 1,
            notification_type: NOTIFICATION_TYPES.liked_consolidated,
            read: true,
            high_priority: false,
            created_at: "2021-11-25T19:31:13.241Z",
            post_number: 6,
            topic_id: 10,
            fancy_title: "Greetings 123!",
            slug: "greetings 123",
            data: {
              topic_title: "Greetings 123!",
              original_post_id: 20,
              original_post_type: 1,
              original_username: "discobot",
              revision_number: null,
              display_username: "discobot",
            },
          },
        ];
      } else if (
        queryParams.filter_by_types ===
        "mentioned,group_mentioned,posted,quoted,replied"
      ) {
        data = [
          {
            id: 6,
            user_id: 1,
            notification_type: NOTIFICATION_TYPES.mentioned,
            read: true,
            high_priority: false,
            created_at: "2021-11-25T19:31:13.241Z",
            post_number: 6,
            topic_id: 10,
            fancy_title: "Greetings!",
            slug: "greetings",
            data: {
              topic_title: "Greetings!",
              original_post_id: 20,
              original_post_type: 1,
              original_username: "discobot",
              revision_number: null,
              display_username: "discobot",
            },
          },
        ];
      } else {
        throw new Error(
          `unexpected notification type ${queryParams.filter_by_types}`
        );
      }

      return [
        200,
        { "Content-Type": "application/json" },
        { notifications: data },
      ];
    });

    await click("#user-menu-button-likes");
    assert.dom("#quick-access-likes.quick-access-panel").exists();
    assert.strictEqual(
      queryParams.filter_by_types,
      "liked,liked_consolidated,reaction",
      "request params has filter_by_types set to `liked`, `liked_consolidated` and `reaction`"
    );
    assert.strictEqual(queryParams.silent, "true");
    let activeTabs = queryAll(".top-tabs .btn.active");
    assert.strictEqual(activeTabs.length, 1);
    assert.strictEqual(
      activeTabs[0].id,
      "user-menu-button-likes",
      "active tab is now the likes tab"
    );
    assert.strictEqual(queryAll("#quick-access-likes ul li").length, 3);

    await click("#user-menu-button-replies");
    assert.dom("#quick-access-replies.quick-access-panel").exists();
    assert.strictEqual(
      queryParams.filter_by_types,
      "mentioned,group_mentioned,posted,quoted,replied",
      "request params has filter_by_types set to `mentioned`, `posted`, `quoted` and `replied`"
    );
    assert.strictEqual(queryParams.silent, "true");
    activeTabs = queryAll(".top-tabs .btn.active");
    assert.strictEqual(activeTabs.length, 1);
    assert.strictEqual(
      activeTabs[0].id,
      "user-menu-button-replies",
      "active tab is now the replies tab"
    );

    await click("#user-menu-button-review-queue");
    assert.dom("#quick-access-review-queue.quick-access-panel").exists();
    activeTabs = queryAll(".top-tabs .btn.active");
    assert.strictEqual(activeTabs.length, 1);
    assert.strictEqual(
      activeTabs[0].id,
      "user-menu-button-review-queue",
      "active tab is now the reviewables tab"
    );
    assert.strictEqual(queryAll("#quick-access-review-queue ul li").length, 8);
  });

  test("count on the likes tab", async function (assert) {
    this.currentUser.set("grouped_unread_notifications", {
      [NOTIFICATION_TYPES.liked]: 1,
      [NOTIFICATION_TYPES.liked_consolidated]: 2,
      [NOTIFICATION_TYPES.reaction]: 3,
      [NOTIFICATION_TYPES.bookmark_reminder]: 10,
    });
    await render(template);

    const likesCountBadge = query(
      "#user-menu-button-likes .badge-notification"
    );
    assert.strictEqual(
      likesCountBadge.textContent,
      (1 + 2 + 3).toString(),
      "combines unread counts for `liked`, `liked_consolidated` and `reaction` types"
    );
  });
});

import { click, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Menu from "discourse/components/user-menu/menu";
import { registerUserMenuTab } from "discourse/lib/user-menu/tab";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import NotificationFixtures from "discourse/tests/fixtures/notification-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

module("Integration | Component | UserMenu", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_user_menu_mentions_tab = true;
  });

  test("new users only see navigation tabs before receiving notifications", async function (assert) {
    this.currentUser.set("available_notification_types", []);
    this.currentUser.set("can_send_private_messages", true);
    await render(<template><Menu /></template>);

    assert.deepEqual(
      findAll(".user-menu-tab").map((tab) => tab.id),
      [
        "user-menu-button-all-notifications",
        "user-menu-button-messages",
        "user-menu-button-bookmarks",
        "user-menu-button-profile",
      ],
      "empty notification filters are hidden while navigation remains available"
    );
    assert.deepEqual(
      findAll(".user-menu-tab").map((tab) => tab.dataset.tabNumber),
      ["0", "1", "2", "3"],
      "keyboard tab positions remain consecutive"
    );
  });

  test("read notifications reveals filters without unread badges", async function (assert) {
    this.currentUser.set("available_notification_types", [
      NOTIFICATION_TYPES.mentioned,
      NOTIFICATION_TYPES.liked,
      NOTIFICATION_TYPES.edited,
    ]);
    this.currentUser.set("grouped_unread_notifications", {});
    await render(<template><Menu /></template>);

    assert
      .dom("#user-menu-button-mentions")
      .exists("a past direct mention reveals Mentions");
    assert.dom("#user-menu-button-likes").exists("a past like reveals Likes");
    assert
      .dom("#user-menu-button-other-notifications")
      .exists("a past edit reveals Other notifications");
    assert
      .dom("#user-menu-button-replies")
      .doesNotExist(
        "a direct mention does not reveal Replies when Mentions is enabled"
      );
    assert
      .dom(".user-menu .badge-notification")
      .doesNotExist("read history does not add unread badges");
  });

  test("direct mentions reveal Replies when the mentions feature is disabled", async function (assert) {
    this.siteSettings.enable_user_menu_mentions_tab = false;
    this.currentUser.set("available_notification_types", [
      NOTIFICATION_TYPES.mentioned,
    ]);
    await render(<template><Menu /></template>);

    assert
      .dom("#user-menu-button-replies")
      .exists("Replies is the applicable filter for direct mentions");
    assert
      .dom("#user-menu-button-mentions")
      .doesNotExist("the disabled feature stays hidden");
    assert
      .dom("#user-menu-button-other-notifications")
      .doesNotExist("mentions are not reassigned to Other");
  });

  test("hidden filters do not move their types into Other notifications", async function (assert) {
    let requestedTypes;
    pretender.get("/notifications", (request) => {
      requestedTypes = request.queryParams.filter_by_types;
      return [
        200,
        { "Content-Type": "application/json" },
        { notifications: [] },
      ];
    });
    this.currentUser.set("available_notification_types", [
      NOTIFICATION_TYPES.edited,
    ]);
    await render(<template><Menu /></template>);
    await click("#user-menu-button-other-notifications");

    assert.false(
      requestedTypes.split(",").includes("liked"),
      "hidden Likes still owns like notifications"
    );
    assert.false(
      requestedTypes.split(",").includes("replied"),
      "hidden Replies still owns reply notifications"
    );
    assert.false(
      requestedTypes.split(",").includes("mentioned"),
      "hidden Mentions still owns direct mentions"
    );
  });

  test("Other excludes plugin-owned types while retaining its own notifications", async function (assert) {
    registerUserMenuTab(
      (UserMenuTab) =>
        class extends UserMenuTab {
          id = "plugin-notifications";
          icon = "comment";
          panelComponent = DButton;
          notificationTypes = ["chat_mention"];

          get title() {
            return "Plugin notifications";
          }
        }
    );
    this.currentUser.set("available_notification_types", [
      NOTIFICATION_TYPES.chat_mention,
      NOTIFICATION_TYPES.edited,
    ]);
    let requestedTypes;
    pretender.get("/notifications", (request) => {
      requestedTypes = request.queryParams.filter_by_types;
      return [
        200,
        { "Content-Type": "application/json" },
        { notifications: [] },
      ];
    });
    await render(<template><Menu /></template>);
    assert
      .dom("#user-menu-button-plugin-notifications")
      .exists("plugin tab remains available");
    await click("#user-menu-button-other-notifications");
    assert.false(
      requestedTypes.split(",").includes("chat_mention"),
      "Other does not absorb the plugin-owned notification type"
    );
    assert.true(
      requestedTypes.split(",").includes("edited"),
      "Other still includes its own notification type"
    );
  });

  test("disabling Likes preserves its existing classification into Other", async function (assert) {
    this.currentUser.set("user_option.likes_notifications_disabled", true);
    this.currentUser.set("available_notification_types", [
      NOTIFICATION_TYPES.liked,
    ]);
    await render(<template><Menu /></template>);

    assert
      .dom("#user-menu-button-likes")
      .doesNotExist("the user preference still hides Likes");
    assert
      .dom("#user-menu-button-other-notifications")
      .exists("Other retains the disabled tab's notification types");
  });

  test("missing availability data preserves tabs for older servers", async function (assert) {
    this.currentUser.set("available_notification_types", null);
    await render(<template><Menu /></template>);

    for (const id of ["replies", "mentions", "likes", "other-notifications"]) {
      assert
        .dom(`#user-menu-button-${id}`)
        .exists("tabs remain usable without availability data");
    }
  });

  test("mentions tab is hidden when the upcoming change is disabled", async function (assert) {
    this.siteSettings.enable_user_menu_mentions_tab = false;
    this.currentUser.set("grouped_unread_notifications", {
      [NOTIFICATION_TYPES.mentioned]: 2,
      [NOTIFICATION_TYPES.group_mentioned]: 3,
      [NOTIFICATION_TYPES.replied]: 4,
    });
    let filterByTypes;
    pretender.get("/notifications", (request) => {
      filterByTypes = request.queryParams.filter_by_types;
      return [
        200,
        { "Content-Type": "application/json" },
        { notifications: [] },
      ];
    });
    await render(<template><Menu /></template>);

    assert
      .dom("#user-menu-button-mentions")
      .doesNotExist("the mentions tab is hidden while the change is disabled");
    assert
      .dom("#user-menu-button-replies")
      .exists("the existing Replies tab remains available");
    assert
      .dom("#user-menu-button-replies .badge-notification")
      .hasText(
        "9",
        "direct mentions are still counted in Replies when disabled"
      );
    await click("#user-menu-button-replies");
    assert.strictEqual(
      filterByTypes,
      "mentioned,group_mentioned,posted,quoted,replied",
      "Replies retains direct mentions when the change is disabled"
    );
  });
  test("replies exclude direct mentions from their filter, count and dismissal when enabled", async function (assert) {
    this.currentUser.set("grouped_unread_notifications", {
      [NOTIFICATION_TYPES.mentioned]: 2,
      [NOTIFICATION_TYPES.group_mentioned]: 3,
      [NOTIFICATION_TYPES.replied]: 4,
    });
    let filterByTypes;
    let dismissTypes;
    pretender.get("/notifications", (request) => {
      filterByTypes = request.queryParams.filter_by_types;
      return [
        200,
        { "Content-Type": "application/json" },
        {
          notifications: [
            NotificationFixtures["/notifications"].notifications[1],
          ],
        },
      ];
    });
    pretender.put("/notifications/mark-read", (request) => {
      dismissTypes = new URLSearchParams(request.requestBody).get(
        "dismiss_types"
      );
      return [200, { "Content-Type": "application/json" }, { success: true }];
    });

    await render(<template><Menu /></template>);
    assert
      .dom("#user-menu-button-replies .badge-notification")
      .hasText("7", "direct mentions are excluded from the Replies badge");
    await click("#user-menu-button-replies");
    assert.strictEqual(
      filterByTypes,
      "group_mentioned,posted,quoted,replied",
      "Replies includes group mentions but not direct mentions"
    );
    await click(".user-menu .notifications-dismiss");
    assert.strictEqual(
      dismissTypes,
      "group_mentioned,posted,quoted,replied",
      "dismissing Replies excludes direct mentions"
    );
    assert
      .dom("#user-menu-button-mentions .badge-notification")
      .hasText("2", "direct mentions remain unread after dismissing Replies");
  });

  test("default tab is all notifications", async function (assert) {
    await render(<template><Menu /></template>);

    assert
      .dom(".top-tabs.tabs-list .btn.active")
      .hasAttribute("id", "user-menu-button-all-notifications");

    const notifications = findAll("#quick-access-all-notifications ul li");
    assert.dom(notifications[0]).hasClass("edited");
    assert.dom(notifications[1]).hasClass("replied");
    assert.dom(notifications[2]).hasClass("liked-consolidated");
  });

  test("active tab has a11y attributes that indicate it's active", async function (assert) {
    await render(<template><Menu /></template>);
    assert.dom(".top-tabs.tabs-list .btn.active").hasAttribute("tabindex", "0");
    assert.dom(".top-tabs.tabs-list .btn.active").hasAria("selected", "true");
  });

  test("inactive tab has a11y attributes that indicate it's inactive", async function (assert) {
    await render(<template><Menu /></template>);
    assert
      .dom(".top-tabs.tabs-list .btn:not(.active)")
      .hasAttribute("tabindex", "-1");
    assert
      .dom(".top-tabs.tabs-list .btn:not(.active)")
      .hasAria("selected", "false");
  });

  test("the menu has a group of tabs at the top", async function (assert) {
    this.currentUser.set("can_send_private_messages", true);
    await render(<template><Menu /></template>);
    const tabs = findAll(".top-tabs.tabs-list .btn");
    assert.strictEqual(tabs.length, 7);
    [
      "all-notifications",
      "replies",
      "mentions",
      "likes",
      "messages",
      "bookmarks",
    ].forEach((tab, index) => {
      assert.strictEqual(tabs[index].id, `user-menu-button-${tab}`);
      assert.strictEqual(tabs[index].dataset.tabNumber, index.toString());
      assert.dom(tabs[index]).hasAria("controls", `quick-access-${tab}`);
    });
  });

  test("the menu has a group of tabs at the bottom", async function (assert) {
    this.currentUser.set("can_send_private_messages", true);
    await render(<template><Menu /></template>);
    const tabs = findAll(".bottom-tabs.tabs-list .btn");
    assert.strictEqual(tabs.length, 1);
    const profileTab = tabs[0];
    assert.strictEqual(profileTab.id, "user-menu-button-profile");
    assert.strictEqual(profileTab.dataset.tabNumber, "7");
    assert.dom(profileTab).hasAttribute("tabindex", "-1");
  });

  test("likes tab is hidden if current user's like notifications frequency is 'never'", async function (assert) {
    this.currentUser.set("user_option.likes_notifications_disabled", true);
    this.currentUser.set("can_send_private_messages", true);
    await render(<template><Menu /></template>);
    assert.dom("#user-menu-button-likes").doesNotExist();

    const tabs = findAll(".tabs-list .btn"); // top and bottom tabs
    assert.strictEqual(tabs.length, 7);

    assert.deepEqual(
      tabs.map((t) => t.dataset.tabNumber),
      ["0", "1", "2", "3", "4", "5", "6"],
      "data-tab-number of the tabs has no gaps when the likes tab is hidden"
    );
  });

  test("reviewables tab is shown if current user can review and there are pending reviewables", async function (assert) {
    this.currentUser.set("can_review", true);
    this.currentUser.set("reviewable_count", 1);
    this.currentUser.set("can_send_private_messages", true);
    await render(<template><Menu /></template>);

    assert
      .dom("#user-menu-button-review-queue")
      .hasAttribute("data-tab-number", "6");

    const tabs = findAll(".tabs-list .btn"); // top and bottom tabs
    assert.strictEqual(tabs.length, 9);

    assert.deepEqual(
      tabs.map((t) => t.dataset.tabNumber),
      ["0", "1", "2", "3", "4", "5", "6", "7", "8"],
      "data-tab-number of the tabs has no gaps when the reviewables tab is show"
    );
  });

  test("reviewables tab is not shown if current user can review but there are no pending reviewables", async function (assert) {
    this.currentUser.set("can_review", true);
    this.currentUser.set("reviewable_count", 0);
    await render(<template><Menu /></template>);
    assert.dom("#user-menu-button-review-queue").doesNotExist();
  });

  test("messages tab isn't shown if current user does not have can_send_private_messages permission", async function (assert) {
    this.currentUser.set("moderator", false);
    this.currentUser.set("admin", false);
    this.currentUser.set("visibleGroups", []);
    this.currentUser.set("can_send_private_messages", false);

    await render(<template><Menu /></template>);

    assert.dom("#user-menu-button-messages").doesNotExist();

    const tabs = findAll(".tabs-list .btn"); // top and bottom tabs
    assert.strictEqual(tabs.length, 7);

    assert.deepEqual(
      tabs.map((t) => t.dataset.tabNumber),
      ["0", "1", "2", "3", "4", "5", "6"],
      "data-tab-number of the tabs has no gaps when the messages tab is hidden"
    );
  });

  test("messages tab is shown if user has can_send_private_messages permission", async function (assert) {
    this.currentUser.set("moderator", true);
    this.currentUser.set("admin", false);
    this.currentUser.set("visibleGroups", []);
    this.currentUser.set("can_send_private_messages", true);

    await render(<template><Menu /></template>);

    assert.dom("#user-menu-button-messages").exists();
  });

  test("reviewables count is shown on the reviewables tab", async function (assert) {
    this.currentUser.set("can_review", true);
    this.currentUser.set("reviewable_count", 4);
    await render(<template><Menu /></template>);
    assert
      .dom("#user-menu-button-review-queue .badge-notification")
      .hasText("4");

    this.currentUser.set("reviewable_count", 0);
    await settled();

    assert
      .dom("#user-menu-button-review-queue .badge-notification")
      .doesNotExist();
  });

  test("changing tabs", async function (assert) {
    this.currentUser.set("can_review", true);
    this.currentUser.set("reviewable_count", 1);
    await render(<template><Menu /></template>);
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
        queryParams.filter_by_types === "group_mentioned,posted,quoted,replied"
      ) {
        data = [
          {
            id: 6,
            user_id: 1,
            notification_type: NOTIFICATION_TYPES.replied,
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
    let activeTabs = findAll(".top-tabs .btn.active");
    assert.strictEqual(activeTabs.length, 1);
    assert.strictEqual(
      activeTabs[0].id,
      "user-menu-button-likes",
      "active tab is now the likes tab"
    );
    assert.dom("#quick-access-likes ul li").exists({ count: 3 });

    await click("#user-menu-button-replies");
    assert.dom("#quick-access-replies.quick-access-panel").exists();
    assert.strictEqual(
      queryParams.filter_by_types,
      "group_mentioned,posted,quoted,replied",
      "request params include group mentions, posted, quoted and replied notifications"
    );
    assert.strictEqual(queryParams.silent, "true");
    activeTabs = findAll(".top-tabs .btn.active");
    assert.strictEqual(activeTabs.length, 1);
    assert.strictEqual(
      activeTabs[0].id,
      "user-menu-button-replies",
      "active tab is now the replies tab"
    );

    await click("#user-menu-button-review-queue");
    assert.dom("#quick-access-review-queue.quick-access-panel").exists();
    activeTabs = findAll(".top-tabs .btn.active");
    assert.strictEqual(activeTabs.length, 1);
    assert.strictEqual(
      activeTabs[0].id,
      "user-menu-button-review-queue",
      "active tab is now the reviewables tab"
    );
    assert.dom("#quick-access-review-queue ul li").exists({ count: 8 });
  });

  test("mentions tab only requests direct mentions", async function (assert) {
    let queryParams;
    pretender.get("/notifications", (request) => {
      queryParams = request.queryParams;
      const types = queryParams.filter_by_types?.split(",");
      const notifications = [
        "mentioned",
        "group_mentioned",
        "replied",
        "quoted",
      ].map((type, index) => ({
        ...NotificationFixtures["/notifications"].notifications[1],
        id: 1000 + index,
        notification_type: NOTIFICATION_TYPES[type],
      }));
      return [
        200,
        { "Content-Type": "application/json" },
        {
          notifications: notifications.filter(
            (n) =>
              !types ||
              types.some((t) => NOTIFICATION_TYPES[t] === n.notification_type)
          ),
        },
      ];
    });

    await render(<template><Menu /></template>);
    await click("#user-menu-button-mentions");

    assert.strictEqual(
      queryParams.filter_by_types,
      "mentioned",
      "only direct mentions are requested"
    );
    assert.strictEqual(
      queryParams.silent,
      "true",
      "filtering does not mark other notifications seen"
    );
    assert
      .dom("#quick-access-mentions ul")
      .hasAria(
        "labelledby",
        "user-menu-button-mentions",
        "the list is labelled by its tab"
      );
    assert
      .dom("#quick-access-mentions li.notification")
      .exists({ count: 1 }, "only the direct mention is rendered");
    assert
      .dom("#quick-access-mentions li.mentioned")
      .exists("the direct mention is visible");
    assert
      .dom("#user-menu-button-mentions")
      .hasAttribute(
        "href",
        "/u/eviltrout/notifications/mentions",
        "the tab links to mention history"
      );
  });

  test("mentions tab has a dedicated empty state", async function (assert) {
    pretender.get("/notifications", () => [
      200,
      { "Content-Type": "application/json" },
      { notifications: [] },
    ]);
    await render(<template><Menu /></template>);
    await click("#user-menu-button-mentions");

    assert
      .dom("#quick-access-mentions")
      .includesText(
        i18n("user.no_mentions_title"),
        "the empty state describes missing mentions"
      );
    assert
      .dom("#quick-access-mentions")
      .includesText(
        i18n("user.no_mentions_body"),
        "the empty state explains direct mentions"
      );
  });

  test("mentions badge counts only direct mentions and updates dynamically", async function (assert) {
    this.currentUser.set("grouped_unread_notifications", {
      [NOTIFICATION_TYPES.mentioned]: 2,
      [NOTIFICATION_TYPES.group_mentioned]: 3,
      [NOTIFICATION_TYPES.replied]: 4,
    });
    await render(<template><Menu /></template>);

    assert
      .dom("#user-menu-button-mentions .badge-notification")
      .hasText("2", "the badge excludes group mentions and replies");
    assert
      .dom("#user-menu-button-mentions")
      .hasAttribute(
        "title",
        i18n("user_menu.tabs.mentions_with_unread", { count: 2 }),
        "the title includes the unread count"
      );

    this.currentUser.set("grouped_unread_notifications", {
      [NOTIFICATION_TYPES.group_mentioned]: 3,
      [NOTIFICATION_TYPES.replied]: 4,
    });
    await settled();

    assert
      .dom("#user-menu-button-mentions .badge-notification")
      .doesNotExist("there is no badge without unread direct mentions");
    assert
      .dom("#user-menu-button-mentions")
      .hasAttribute(
        "title",
        i18n("user_menu.tabs.mentions"),
        "the title no longer includes an unread count"
      );
  });

  test("dismissing mentions leaves other notification types unread", async function (assert) {
    this.currentUser.set("grouped_unread_notifications", {
      [NOTIFICATION_TYPES.mentioned]: 2,
      [NOTIFICATION_TYPES.group_mentioned]: 3,
      [NOTIFICATION_TYPES.replied]: 4,
    });
    let dismissTypes;
    pretender.put("/notifications/mark-read", (request) => {
      dismissTypes = new URLSearchParams(request.requestBody).get(
        "dismiss_types"
      );
      return [200, { "Content-Type": "application/json" }, { success: true }];
    });

    await render(<template><Menu /></template>);
    await click("#user-menu-button-mentions");
    await click(".user-menu .notifications-dismiss");

    assert.strictEqual(
      dismissTypes,
      "mentioned",
      "only direct mentions are marked read"
    );
    assert
      .dom("#user-menu-button-mentions .badge-notification")
      .doesNotExist("the mentions badge is cleared");
    assert
      .dom("#user-menu-button-replies .badge-notification")
      .hasText("7", "group mentions and replies remain unread");
  });

  test("count on the likes tab", async function (assert) {
    this.currentUser.set("grouped_unread_notifications", {
      [NOTIFICATION_TYPES.liked]: 1,
      [NOTIFICATION_TYPES.liked_consolidated]: 2,
      [NOTIFICATION_TYPES.reaction]: 3,
      [NOTIFICATION_TYPES.bookmark_reminder]: 10,
    });
    await render(<template><Menu /></template>);

    assert
      .dom("#user-menu-button-likes .badge-notification")
      .hasText(
        `${1 + 2 + 3}`,
        "combines unread counts for `liked`, `liked_consolidated` and `reaction` types"
      );
  });
});

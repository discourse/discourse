import { render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import UserMenuFixtures from "discourse/tests/fixtures/user-menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON, deepMerge } from "discourse-common/lib/object";
import I18n from "discourse-i18n";

function getMessage(overrides = {}) {
  return deepMerge(
    {
      id: 8092,
      title: "Test ToPic 4422",
      fancy_title: "Test topic 4422",
      slug: "test-topic-4422",
      posts_count: 1,
      reply_count: 0,
      highest_post_number: 2,
      image_url: null,
      created_at: "2019-07-26T01:29:24.008Z",
      last_posted_at: "2019-07-26T01:29:24.177Z",
      bumped: true,
      bumped_at: "2019-07-26T01:29:24.177Z",
      unseen: false,
      last_read_post_number: 2,
      unread_posts: 0,
      pinned: false,
      unpinned: null,
      visible: true,
      closed: false,
      archived: false,
      notification_level: 3,
      bookmarked: false,
      bookmarks: [],
      liked: false,
      views: 5,
      like_count: 0,
      has_summary: false,
      archetype: "private_message",
      last_poster_username: "mixtape",
      category_id: null,
      pinned_globally: false,
      featured_link: null,
      posters: [
        {
          extras: "latest single",
          description: "Original Poster, Most Recent Poster",
          user_id: 13,
          primary_group_id: null,
        },
      ],
      participants: [
        {
          extras: "latest",
          description: null,
          user_id: 13,
          primary_group_id: null,
        },
      ],
    },
    overrides
  );
}

function getGroupMessageSummaryNotification(overrides = {}) {
  return deepMerge(
    {
      id: 9492,
      user_id: 1,
      notification_type: 16,
      read: true,
      high_priority: false,
      created_at: "2022-08-05T17:27:24.873Z",
      post_number: null,
      topic_id: null,
      fancy_title: null,
      slug: null,
      data: {
        group_id: 1,
        group_name: "jokers",
        inbox_count: 4,
        username: "joker.leader",
      },
    },
    overrides
  );
}

module("Integration | Component | user-menu | messages-list", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`<UserMenu::MessagesList/>`;

  test("renders unread PM notifications first followed by messages and read group_message_summary notifications", async function (assert) {
    pretender.get("/u/eviltrout/user-menu-private-messages", () => {
      const copy = cloneJSON(
        UserMenuFixtures["/u/:username/user-menu-private-messages"]
      );
      copy.read_notifications = [getGroupMessageSummaryNotification()];
      return response(copy);
    });
    await render(template);
    const items = queryAll("ul li");

    assert.strictEqual(items.length, 3);

    assert.ok(items[0].classList.contains("notification"));
    assert.ok(items[0].classList.contains("unread"));
    assert.ok(items[0].classList.contains("private-message"));

    assert.ok(items[1].classList.contains("notification"));
    assert.ok(items[1].classList.contains("read"));
    assert.ok(items[1].classList.contains("group-message-summary"));

    assert.ok(items[2].classList.contains("message"));
  });

  test("does not error when there are no group_message_summary notifications", async function (assert) {
    pretender.get("/u/eviltrout/user-menu-private-messages", () => {
      const copy = cloneJSON(
        UserMenuFixtures["/u/:username/user-menu-private-messages"]
      );
      copy.read_notifications = [];
      return response(copy);
    });

    await render(template);
    const items = queryAll("ul li");

    assert.strictEqual(items.length, 2);

    assert.ok(items[0].classList.contains("notification"));
    assert.ok(items[0].classList.contains("unread"));
    assert.ok(items[0].classList.contains("private-message"));

    assert.ok(items[1].classList.contains("message"));
  });

  test("does not error when there are no messages", async function (assert) {
    pretender.get("/u/eviltrout/user-menu-private-messages", () => {
      const copy = cloneJSON(
        UserMenuFixtures["/u/:username/user-menu-private-messages"]
      );
      copy.topics = [];
      copy.read_notifications = [getGroupMessageSummaryNotification()];
      return response(copy);
    });

    await render(template);
    const items = queryAll("ul li");

    assert.strictEqual(items.length, 2);

    assert.ok(items[0].classList.contains("notification"));
    assert.ok(items[0].classList.contains("unread"));
    assert.ok(items[0].classList.contains("private-message"));

    assert.ok(items[1].classList.contains("notification"));
    assert.ok(items[1].classList.contains("read"));
    assert.ok(items[1].classList.contains("group-message-summary"));
  });

  test("merge-sorts group_message_summary notifications and messages", async function (assert) {
    pretender.get("/u/eviltrout/user-menu-private-messages", () => {
      const copy = cloneJSON(
        UserMenuFixtures["/u/:username/user-menu-private-messages"]
      );
      copy.unread_notifications = [];
      copy.topics = [
        getMessage({
          id: 8090,
          bumped_at: "2014-07-26T01:29:24.177Z",
          fancy_title: "Test Topic 0003",
        }),
        getMessage({
          id: 8091,
          bumped_at: "2012-07-26T01:29:24.177Z",
          fancy_title: "Test Topic 0002",
        }),
        getMessage({
          id: 8092,
          bumped_at: "2010-07-26T01:29:24.177Z",
          fancy_title: "Test Topic 0001",
        }),
      ];
      copy.read_notifications = [
        getGroupMessageSummaryNotification({
          created_at: "2015-07-26T01:29:24.177Z",
          data: {
            inbox_count: 13,
          },
        }),
        getGroupMessageSummaryNotification({
          created_at: "2013-07-26T01:29:24.177Z",
          data: {
            inbox_count: 12,
          },
        }),
        getGroupMessageSummaryNotification({
          created_at: "2011-07-26T01:29:24.177Z",
          data: {
            inbox_count: 11,
          },
        }),
      ];
      return response(copy);
    });
    await render(template);
    const items = queryAll("ul li");

    assert.strictEqual(items.length, 6);

    assert.strictEqual(
      items[0].textContent.trim(),
      I18n.t("notifications.group_message_summary", {
        count: 13,
        group_name: "jokers",
      })
    );

    assert.strictEqual(
      items[1].textContent.trim().replaceAll(/\s+/g, " "),
      "mixtape Test Topic 0003"
    );

    assert.strictEqual(
      items[2].textContent.trim(),
      I18n.t("notifications.group_message_summary", {
        count: 12,
        group_name: "jokers",
      })
    );

    assert.strictEqual(
      items[3].textContent.trim().replaceAll(/\s+/g, " "),
      "mixtape Test Topic 0002"
    );

    assert.strictEqual(
      items[4].textContent.trim(),
      I18n.t("notifications.group_message_summary", {
        count: 11,
        group_name: "jokers",
      })
    );

    assert.strictEqual(
      items[5].textContent.trim().replaceAll(/\s+/g, " "),
      "mixtape Test Topic 0001"
    );
  });

  test("show all button for message notifications", async function (assert) {
    await render(template);
    assert
      .dom(".panel-body-bottom .show-all")
      .hasAttribute(
        "title",
        I18n.t("user_menu.view_all_messages"),
        "has the correct title"
      );
  });

  test("dismiss button", async function (assert) {
    this.currentUser.set("grouped_unread_notifications", {
      [NOTIFICATION_TYPES.private_message]: 72,
    });
    await render(template);

    const dismiss = query(".panel-body-bottom .notifications-dismiss");
    assert.ok(
      dismiss,
      "dismiss button is shown if the user has unread private_message notifications"
    );
    assert
      .dom(".panel-body-bottom .notifications-dismiss")
      .hasAttribute(
        "title",
        I18n.t("user.dismiss_messages_tooltip"),
        "dismiss button has a title"
      );

    this.currentUser.set("grouped_unread_notifications", {});
    await settled();

    assert
      .dom(".panel-body-bottom .notifications-dismiss")
      .doesNotExist(
        "dismiss button is not shown if the user no unread private_message notifications"
      );
  });

  test("empty state (aka blank page syndrome)", async function (assert) {
    pretender.get("/u/eviltrout/user-menu-private-messages", () => {
      return response({
        unread_notifications: [],
        topics: [],
        read_notifications: [],
      });
    });

    await render(template);

    assert.strictEqual(
      query(".empty-state-title").textContent.trim(),
      I18n.t("user.no_messages_title"),
      "empty state title is shown"
    );
    assert
      .dom(".empty-state-body svg.d-icon-envelope")
      .exists("icon is correctly rendered in the empty state body");
    assert
      .dom(".empty-state-body a")
      .hasAttribute(
        "href",
        "/about",
        "link inside empty state body is rendered"
      );
  });
});

import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { cloneJSON } from "discourse/lib/object";
import Site from "discourse/models/site";
import topicFixtures from "discourse/tests/fixtures/discovery-fixtures";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Topic Discovery Tracked", function (needs) {
  needs.user({
    tracked_tags: [1],
    watched_tags: [2],
    watching_first_post_tags: [3],
  });

  needs.pretender((server, helper) => {
    server.get("/c/:category-slug/:category-id/l/latest.json", () => {
      return helper.response(cloneJSON(topicFixtures["/latest.json"]));
    });

    server.get("/tag/:tag_id/notifications.json", () => {
      return helper.response({
        tag_notification: {
          id: "test",
          notification_level: NotificationLevels.TRACKING,
        },
      });
    });

    server.get("/tag/:tag_slug/:tag_id/l/latest.json", (request) => {
      const response = cloneJSON(topicFixtures["/latest.json"]);
      // add tag with id to response so tracking state gets the tag id
      response.topic_list.tags = [
        {
          id: parseInt(request.params.tag_id, 10),
          name: request.params.tag_slug,
          slug: request.params.tag_slug,
        },
      ];
      return helper.response(response);
    });
  });

  test("navigation items with tracked filter", async function (assert) {
    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: 1,
        notification_level: null,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 2,
        highest_post_number: 12,
        last_read_post_number: 11,
        created_at: "2020-02-09T09:40:02.672Z",
        category_id: 2,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
    ]);

    await visit("/");

    assert
      .dom("#navigation-bar li.categories")
      .exists(
        "the categories nav item is displayed when tracked filter is not present"
      );

    await visit("/categories");

    assert
      .dom("#navigation-bar li.categories")
      .exists(
        "the categories nav item is displayed on categories route when tracked filter is not present"
      );

    await visit("/?f=tracked");

    assert
      .dom("#navigation-bar li.categories")
      .doesNotExist(
        "the categories nav item is not displayed when tracked filter is present"
      );

    assert
      .dom("#navigation-bar li.unread a")
      .hasAttribute(
        "href",
        "/unread?f=tracked",
        "unread link has tracked filter"
      );

    assert
      .dom("#navigation-bar li.new a")
      .hasAttribute("href", "/new?f=tracked", "new link has tracked filter");

    assert
      .dom("#navigation-bar li.hot a")
      .hasAttribute("href", "/hot?f=tracked", "hot link has tracked filter");

    assert
      .dom("#navigation-bar li.latest a")
      .hasAttribute(
        "href",
        "/latest?f=tracked",
        "latest link has tracked filter"
      );
  });

  test("visit discovery pages with tracked filter", async function (assert) {
    const categories = Site.current().categories;

    // Category id 1001 has two subcategories
    const category = categories.find((c) => c.id === 1001);
    category.set("notification_level", NotificationLevels.TRACKING);

    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: category.id,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 2,
        highest_post_number: 12,
        last_read_post_number: 11,
        created_at: "2020-02-09T09:40:02.672Z",
        category_id: category.subcategories[0].id,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 3,
        highest_post_number: 12,
        last_read_post_number: 11,
        created_at: "2020-02-09T09:40:02.672Z",
        category_id: category.subcategories[0].subcategories[0].id,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 4,
        highest_post_number: 15,
        last_read_post_number: 14,
        created_at: "2021-06-14T12:41:02.477Z",
        category_id: 3,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 5,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2021-06-14T12:41:02.477Z",
        category_id: 3,
        notification_level: null,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 6,
        highest_post_number: 17,
        last_read_post_number: 16,
        created_at: "2020-10-31T03:41:42.257Z",
        category_id: 1234,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: [{ id: 3 }],
      },
    ]);

    await visit("/");

    assert
      .dom("#navigation-bar li.unread")
      .hasText(
        i18n("filters.unread.title_with_count", { count: 4 }),
        "displays the right content on unread link"
      );

    assert
      .dom("#navigation-bar li.new")
      .hasText(
        i18n("filters.new.title_with_count", { count: 2 }),
        "displays the right content on new link"
      );

    await visit("/?f=tracked");

    assert
      .dom("#navigation-bar li.unread")
      .hasText(
        i18n("filters.unread.title_with_count", { count: 3 }),
        "displays the right content on unread link"
      );

    assert
      .dom("#navigation-bar li.new")
      .hasText(
        i18n("filters.new.title_with_count", { count: 1 }),
        "displays the right content on new link"
      );

    // simulate reading topic id 1
    await publishToMessageBus("/unread", {
      topic_id: 1,
      message_type: "read",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 1,
      },
    });

    // simulate reading topic id 3
    await publishToMessageBus("/unread", {
      topic_id: 3,
      message_type: "read",
      payload: {
        last_read_post_number: 12,
        highest_post_number: 12,
      },
    });

    assert
      .dom("#navigation-bar li.unread")
      .hasText(
        i18n("filters.unread.title_with_count", { count: 2 }),
        "displays the right content on unread link"
      );

    assert
      .dom("#navigation-bar li.new")
      .hasText(
        i18n("filters.new.title"),
        "displays the right content on new link"
      );
  });

  test("visit discovery page filtered by tag with tracked filter", async function (assert) {
    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: 1,
        notification_level: null,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: [{ id: 99 }],
      },
    ]);

    await visit("/tag/some-other-tag/99");

    assert
      .dom("#navigation-bar li.unread")
      .hasText(
        i18n("filters.unread.title"),
        "displays the right content on unread link"
      );

    assert
      .dom("#navigation-bar li.new")
      .hasText(
        i18n("filters.new.title_with_count", { count: 1 }),
        "displays the right content on new link"
      );

    await visit("/tag/some-other-tag/99?f=tracked");

    assert
      .dom("#navigation-bar li.unread")
      .hasText(
        i18n("filters.unread.title"),
        "displays the right content on unread link"
      );

    assert
      .dom("#navigation-bar li.new")
      .hasText(
        i18n("filters.new.title"),
        "displays the right content on new link"
      );
  });

  test("visit discovery page filtered by category with tracked filter", async function (assert) {
    const categories = Site.current().categories;
    const category = categories.at(-1);
    category.set("notification_level", NotificationLevels.TRACKING);

    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: category.id,
        notification_level: null,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 2,
        highest_post_number: 12,
        last_read_post_number: 11,
        created_at: "2020-02-09T09:40:02.672Z",
        category_id: category.id,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 3,
        highest_post_number: 15,
        last_read_post_number: 14,
        created_at: "2021-06-14T12:41:02.477Z",
        category_id: 3,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
      },
      {
        topic_id: 4,
        highest_post_number: 17,
        last_read_post_number: 16,
        created_at: "2020-10-31T03:41:42.257Z",
        category_id: 1234,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: [{ id: 3 }],
      },
    ]);

    await visit(`/c/3`);

    assert
      .dom("#navigation-bar li.unread")
      .hasText(
        i18n("filters.unread.title_with_count", { count: 1 }),
        "displays the right content on unread link"
      );

    assert
      .dom("#navigation-bar li.new")
      .hasText(
        i18n("filters.new.title"),
        "displays the right content on new link"
      );

    await visit(`/c/3?f=tracked`);

    assert
      .dom("#navigation-bar li.unread")
      .hasText(
        i18n("filters.unread.title"),
        "displays the right content on unread link"
      );

    assert
      .dom("#navigation-bar li.new")
      .hasText(
        i18n("filters.new.title"),
        "displays the right content on new link"
      );
  });
});

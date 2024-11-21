import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { NotificationLevels } from "discourse/lib/notification-levels";
import discoveryFixture from "discourse/tests/fixtures/discovery-fixtures";
import {
  acceptance,
  publishToMessageBus,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

acceptance("Sidebar - Logged on user - Tags section", function (needs) {
  needs.settings({
    tagging_enabled: true,
    navigation_menu: "sidebar",
  });

  needs.user({
    tracked_tags: ["tag1"],
    watched_tags: ["tag2", "tag3"],
    watching_first_post_tags: [],
    sidebar_tags: [
      { name: "tag2", pm_only: false },
      { name: "tag1", pm_only: false },
      {
        name: "tag4",
        pm_only: true,
      },
      {
        name: "tag3",
        pm_only: false,
      },
    ],
    display_sidebar_tags: true,
    admin: false,
  });

  needs.pretender((server, helper) => {
    server.get("/tag/:tagId/notifications", (request) => {
      return helper.response({
        tag_notification: { id: request.params.tagId },
      });
    });

    server.get("/topics/private-messages-tags/:username/:tagId", () => {
      const topics = [
        { id: 1, posters: [] },
        { id: 2, posters: [] },
        { id: 3, posters: [] },
      ];

      return helper.response({
        topic_list: {
          topics,
        },
      });
    });

    ["latest", "top", "new", "unread"].forEach((type) => {
      server.get(`/tag/:tagId/l/${type}.json`, () => {
        return helper.response(
          cloneJSON(discoveryFixture["/tag/important/l/latest.json"])
        );
      });
    });
  });

  test("tag section links for user", async function (assert) {
    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link:not(.sidebar-section-link[data-link-name='all-tags'])"
      )
      .exists({ count: 4 }, "4 section links under the section");

    assert.strictEqual(
      query(
        ".sidebar-section-link-wrapper[data-tag-name=tag1]"
      ).textContent.trim(),
      "tag1",
      "displays the tag1 name for the link text"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-link-wrapper[data-tag-name=tag2]"
      ).textContent.trim(),
      "tag2",
      "displays the tag2 name for the link text"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-link-wrapper[data-tag-name=tag3]"
      ).textContent.trim(),
      "tag3",
      "displays the tag3 name for the link text"
    );

    await click(".sidebar-section-link-wrapper[data-tag-name=tag1] a");

    assert.strictEqual(
      currentURL(),
      "/tag/tag1",
      "it should transition to tag1's topics discovery page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(`.sidebar-section-link-wrapper[data-tag-name=tag1] a.active`)
      .exists("the tag1 section link is marked as active");

    await click(".sidebar-section-link-wrapper[data-tag-name=tag2] a");

    assert.strictEqual(
      currentURL(),
      "/tag/tag2",
      "it should transition to tag2's topics discovery page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(`.sidebar-section-link-wrapper[data-tag-name=tag2] a.active`)
      .exists("the tag2 section link is marked as active");
  });

  test("clicking tag section links - sidebar_link_to_filtered_list set to true and no unread or new topics", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });

    await visit("/");
    await click(".sidebar-section-link-wrapper[data-tag-name=tag1] a");

    assert.strictEqual(
      currentURL(),
      "/tag/tag1",
      "it should transition to tag1's topics discovery page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(`.sidebar-section-link-wrapper[data-tag-name=tag1] a.active`)
      .exists("the tag1 section link is marked as active");
  });

  test("clicking tag section links - sidebar_link_to_filtered_list set to true with new topics", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });

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
        tags: ["tag1"],
      },
    ]);

    await visit("/");
    await click(".sidebar-section-link-wrapper[data-tag-name=tag1] a");

    assert.strictEqual(
      currentURL(),
      "/tag/tag1/l/new",
      "it should transition to tag1's topics new page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(`.sidebar-section-link-wrapper[data-tag-name=tag1] a.active`)
      .exists("the tag1 section link is marked as active");
  });

  test("clicking tag section links - sidebar_link_to_filtered_list set to true with unread topics", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });

    this.container.lookup("service:topic-tracking-state").loadStates([
      {
        topic_id: 1,
        highest_post_number: 2,
        last_read_post_number: 1,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: 1,
        notification_level: NotificationLevels.TRACKING,
        created_in_new_period: true,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: ["tag1"],
      },
    ]);

    await visit("/");
    await click(".sidebar-section-link-wrapper[data-tag-name=tag1] a");

    assert.strictEqual(
      currentURL(),
      "/tag/tag1/l/unread",
      "it should transition to tag1's topics unread page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(`.sidebar-section-link-wrapper[data-tag-name=tag1] a.active`)
      .exists("the tag1 section link is marked as active");
  });

  test("private message tag section links for user", async function (assert) {
    await visit("/");

    await click(".sidebar-section-link-wrapper[data-tag-name=tag4] a");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/messages/tags/tag4",
      "it should transition to user's private message tag4 tag page"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(`.sidebar-section-link-wrapper[data-tag-name=tag4] a.active`)
      .exists("the tag4 section link is marked as active");
  });

  test("visiting tag discovery top route", async function (assert) {
    await visit(`/tag/tag1/l/top`);

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(".sidebar-section-link-wrapper[data-tag-name=tag1] a.active")
      .exists("the tag1 section link is marked as active for the top route");
  });

  test("visiting tag discovery new ", async function (assert) {
    await visit(`/tag/tag1/l/new`);

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(".sidebar-section-link-wrapper[data-tag-name=tag1] a.active")
      .exists("the tag1 section link is marked as active for the new route");
  });

  test("visiting tag discovery unread route", async function (assert) {
    await visit(`/tag/tag1/l/unread`);

    assert
      .dom(
        ".sidebar-section[data-section-name='tags'] .sidebar-section-link.active"
      )
      .exists({ count: 1 }, "only one link is marked as active");

    assert
      .dom(".sidebar-section-link-wrapper[data-tag-name=tag1] a.active")
      .exists("the tag1 section link is marked as active for the unread route");
  });

  test("show suffix indicator for new content on tag section links", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_show_count_of_new_items: false,
      },
    });

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
        tags: ["tag1"],
      },
      {
        topic_id: 2,
        highest_post_number: 12,
        last_read_post_number: 11,
        created_at: "2020-02-09T09:40:02.672Z",
        category_id: 2,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: ["tag1"],
      },
      {
        topic_id: 3,
        highest_post_number: 15,
        last_read_post_number: 14,
        created_at: "2021-06-14T12:41:02.477Z",
        category_id: 3,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: ["tag2"],
      },
    ]);

    await visit("/");

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-tag-name=tag1] .sidebar-section-link-suffix`
      )
      .exists("shows suffix indicator for new content on tag1 link");

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-tag-name=tag2] .sidebar-section-link-suffix`
      )
      .exists("shows suffix indicator for new content on tag2 link");

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-tag-name=tag3] .sidebar-section-link-suffix`
      )
      .doesNotExist(
        "hides suffix indicator when there's no new content on tag3 link"
      );

    await publishToMessageBus("/unread", {
      topic_id: 2,
      message_type: "read",
      payload: {
        last_read_post_number: 12,
        highest_post_number: 12,
      },
    });

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-tag-name=tag1] .sidebar-section-link-suffix`
      )
      .exists("shows suffix indicator for new topic on tag1 link");

    await publishToMessageBus("/unread", {
      topic_id: 1,
      message_type: "read",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 1,
      },
    });

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-tag-name=tag1] .sidebar-section-link-suffix`
      )
      .doesNotExist("hides suffix indicator for tag1 section link");
  });

  test("new and unread count for tag section links", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_show_count_of_new_items: true,
      },
    });

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
        tags: ["tag1"],
      },
      {
        topic_id: 2,
        highest_post_number: 12,
        last_read_post_number: 11,
        created_at: "2020-02-09T09:40:02.672Z",
        category_id: 2,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: ["tag1"],
      },
      {
        topic_id: 3,
        highest_post_number: 15,
        last_read_post_number: 14,
        created_at: "2021-06-14T12:41:02.477Z",
        category_id: 3,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: ["tag2"],
      },
      {
        topic_id: 4,
        highest_post_number: 17,
        last_read_post_number: 16,
        created_at: "2020-10-31T03:41:42.257Z",
        category_id: 4,
        notification_level: 2,
        created_in_new_period: false,
        treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        tags: ["tag4"],
      },
    ]);

    await visit("/");

    assert.strictEqual(
      query(
        `.sidebar-section-link-wrapper[data-tag-name=tag1] .sidebar-section-link-content-badge`
      ).textContent.trim(),
      i18n("sidebar.unread_count", { count: 1 }),
      `displays 1 unread count for tag1 section link`
    );

    assert.strictEqual(
      query(
        `.sidebar-section-link-wrapper[data-tag-name=tag2] .sidebar-section-link-content-badge`
      ).textContent.trim(),
      i18n("sidebar.unread_count", { count: 1 }),
      `displays 1 unread count for tag2 section link`
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-tag-name=tag3] .sidebar-section-link-content-badge`
      )
      .doesNotExist("does not display any badge for tag3 section link");

    await publishToMessageBus("/unread", {
      topic_id: 2,
      message_type: "read",
      payload: {
        last_read_post_number: 12,
        highest_post_number: 12,
      },
    });

    assert.strictEqual(
      query(
        `.sidebar-section-link-wrapper[data-tag-name=tag1] .sidebar-section-link-content-badge`
      ).textContent.trim(),
      i18n("sidebar.new_count", { count: 1 }),
      `displays 1 new count for tag1 section link`
    );

    await publishToMessageBus("/unread", {
      topic_id: 1,
      message_type: "read",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 1,
      },
    });

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-tag-name=tag1] .sidebar-section-link-content-badge`
      )
      .doesNotExist(`does not display any badge tag1 section link`);
  });

  test("cleans up topic tracking state state changed callbacks when section is destroyed", async function (assert) {
    await visit("/");

    const topicTrackingState = this.container.lookup(
      "service:topic-tracking-state"
    );

    const initialCallbackCount = Object.keys(
      topicTrackingState.stateChangeCallbacks
    ).length;

    await click(".btn-sidebar-toggle");

    assert.ok(
      Object.keys(topicTrackingState.stateChangeCallbacks).length <
        initialCallbackCount
    );
  });

  test("section link to admin site settings page when default sidebar tags have not been configured", async function (assert) {
    updateCurrentUser({ admin: true, sidebar_tags: [] });

    updateCurrentUser({
      sidebar_tags: [],
    });

    await visit("/");

    assert
      .dom(
        ".sidebar-section-link[data-link-name='configure-default-navigation-menu-tags']"
      )
      .exists("section link to configure default sidebar tags is shown");

    await click(
      ".sidebar-section-link[data-link-name='configure-default-navigation-menu-tags']"
    );

    assert.strictEqual(
      currentURL(),
      "/admin/site_settings/category/all_results?filter=default_navigation_menu_tags",
      "it links to the admin site settings page correctly"
    );
  });
});

acceptance(
  "Sidebar - Logged on user - Tags section - New new view enabled",
  function (needs) {
    needs.settings({
      tagging_enabled: true,
      navigation_menu: "sidebar",
    });

    needs.user({
      new_new_view_enabled: true,
      display_sidebar_tags: true,
      sidebar_tags: [
        { name: "tag2", pm_only: false },
        { name: "tag1", pm_only: false },
        { name: "tag3", pm_only: false },
      ],
    });

    test("count shown next to tag link when sidebar_show_count_of_new_items is true", async function (assert) {
      updateCurrentUser({
        user_option: {
          sidebar_show_count_of_new_items: true,
        },
      });

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
          tags: ["tag1", "tag3"],
        },
        {
          topic_id: 2,
          highest_post_number: 12,
          last_read_post_number: 11,
          created_at: "2020-02-09T09:40:02.672Z",
          category_id: 2,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
          tags: ["tag1", "tag2"],
        },
        {
          topic_id: 3,
          highest_post_number: 15,
          last_read_post_number: 15,
          created_at: "2021-06-14T12:41:02.477Z",
          category_id: 3,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
          tags: ["tag1"],
        },
      ]);

      await visit("/");

      assert.strictEqual(
        query(
          '.sidebar-section-link-wrapper[data-tag-name="tag1"] .sidebar-section-link-content-badge'
        ).textContent.trim(),
        "2",
        "count for tag1 is 2 because it has 1 unread topic and 1 new topic"
      );

      assert.strictEqual(
        query(
          '.sidebar-section-link-wrapper[data-tag-name="tag2"] .sidebar-section-link-content-badge'
        ).textContent.trim(),
        "1",
        "count for tag2 is 1 because it has 1 unread topic"
      );

      assert.strictEqual(
        query(
          '.sidebar-section-link-wrapper[data-tag-name="tag3"] .sidebar-section-link-content-badge'
        ).textContent.trim(),
        "1",
        "count for tag3 is 1 because it has 1 new topic"
      );
    });

    test("dot shown next to tag link when sidebar_show_count_of_new_items is false", async function (assert) {
      updateCurrentUser({
        user_option: {
          sidebar_show_count_of_new_items: false,
        },
      });

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
          tags: ["tag1"],
        },
        {
          topic_id: 2,
          highest_post_number: 12,
          last_read_post_number: 11,
          created_at: "2020-02-09T09:40:02.672Z",
          category_id: 2,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
          tags: ["tag2"],
        },
      ]);

      await visit("/");

      assert
        .dom(
          '.sidebar-section-link-wrapper[data-tag-name="tag1"] .sidebar-section-link-suffix.icon.unread'
        )
        .exists("tag1 has a dot because it has a new topic");
      assert
        .dom(
          '.sidebar-section-link-wrapper[data-tag-name="tag2"] .sidebar-section-link-suffix.icon.unread'
        )
        .exists("tag2 has a dot because it has an unread topic");
      assert
        .dom(
          '.sidebar-section-link-wrapper[data-tag-name="tag3"] .sidebar-section-link-suffix.icon.unread'
        )
        .doesNotExist(
          "tag3 doesn't have a dot because it has no new or unread topics"
        );
    });

    test("tag link href is to the new topics list when sidebar_link_to_filtered_list is true and there are unread/new topics with the tag", async function (assert) {
      updateCurrentUser({
        user_option: {
          sidebar_link_to_filtered_list: true,
        },
      });

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
          tags: ["tag1"],
        },
        {
          topic_id: 2,
          highest_post_number: 12,
          last_read_post_number: 11,
          created_at: "2020-02-09T09:40:02.672Z",
          category_id: 2,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
          tags: ["tag2"],
        },
        {
          topic_id: 3,
          highest_post_number: 15,
          last_read_post_number: 15,
          created_at: "2021-06-14T12:41:02.477Z",
          category_id: 3,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
          tags: ["tag3"],
        },
      ]);

      await visit("/");

      assert
        .dom('.sidebar-section-link-wrapper[data-tag-name="tag1"] a')
        .hasAttribute(
          "href",
          "/tag/tag1/l/new",
          "links to the new topics list for the tag because there's 1 new topic"
        );

      assert
        .dom('.sidebar-section-link-wrapper[data-tag-name="tag2"] a')
        .hasAttribute(
          "href",
          "/tag/tag2/l/new",
          "links to the new topics list for the tag because there's 1 unread topic"
        );

      assert
        .dom('.sidebar-section-link-wrapper[data-tag-name="tag3"] a')
        .hasAttribute(
          "href",
          "/tag/tag3",
          "links to the latest topics list for the tag because there are no unread or new topics"
        );
    });

    test("tag link href is always to the latest topics list when sidebar_link_to_filtered_list is false", async function (assert) {
      updateCurrentUser({
        user_option: {
          sidebar_link_to_filtered_list: false,
        },
      });

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
          tags: ["tag1"],
        },
        {
          topic_id: 2,
          highest_post_number: 12,
          last_read_post_number: 11,
          created_at: "2020-02-09T09:40:02.672Z",
          category_id: 2,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
          tags: ["tag2"],
        },
      ]);

      await visit("/");

      assert
        .dom('.sidebar-section-link-wrapper[data-tag-name="tag1"] a')
        .hasAttribute(
          "href",
          "/tag/tag1",
          "tag1 links to the latest topics list for the tag"
        );

      assert
        .dom('.sidebar-section-link-wrapper[data-tag-name="tag2"] a')
        .hasAttribute(
          "href",
          "/tag/tag2",
          "tag2 links to the latest topics list for the tag"
        );

      assert
        .dom('.sidebar-section-link-wrapper[data-tag-name="tag3"] a')
        .hasAttribute(
          "href",
          "/tag/tag3",
          "tag3 links to the latest topics list for the tag"
        );
    });
  }
);

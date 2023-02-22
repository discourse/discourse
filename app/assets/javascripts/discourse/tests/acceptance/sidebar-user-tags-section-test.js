import I18n from "I18n";
import { test } from "qunit";
import { click, currentURL, visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  exists,
  publishToMessageBus,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import discoveryFixture from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import { NotificationLevels } from "discourse/lib/notification-levels";

acceptance(
  "Sidebar - Logged on user - Tags section - tagging disabled",
  function (needs) {
    needs.settings({
      tagging_enabled: false,
      navigation_menu: "sidebar",
    });

    needs.user();

    test("tags section is not shown", async function (assert) {
      await visit("/");

      assert.ok(
        !exists(".sidebar-section-tags"),
        "does not display the tags section"
      );
    });
  }
);

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

  test("section is not displayed when display_sidebar_tags property is false", async function (assert) {
    updateCurrentUser({ display_sidebar_tags: false });

    await visit("/");

    assert.notOk(
      exists(".sidebar-section-tags"),
      "tags section is not displayed"
    );
  });

  test("clicking on section header button", async function (assert) {
    await visit("/");
    await click(".sidebar-section-tags .sidebar-section-header-button");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/sidebar",
      "it should transition to user preferences sidebar page"
    );
  });

  test("tags section is hidden when user has not added any tags and there are no default tags configured", async function (assert) {
    updateCurrentUser({
      sidebar_tags: [],
    });

    await visit("/");

    assert.notOk(
      exists(".sidebar-section-tags"),
      "tags section is not displayed"
    );
  });

  test("tags section is shown when user has not added any tags but default tags have been configured", async function (assert) {
    updateCurrentUser({
      sidebar_tags: [],
    });

    this.siteSettings.default_sidebar_tags = "tag1|tag2";

    await visit("/");

    assert.ok(exists(".sidebar-section-tags"), "tags section is shown");

    assert.ok(
      exists(".sidebar-section-tags .sidebar-section-link-configure-tags"),
      "section link to add tags to sidebar is displayed"
    );

    await click(".sidebar-section-tags .sidebar-section-link-configure-tags");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/sidebar",
      "it should transition to user preferences sidebar page"
    );
  });

  test("tag section links are sorted alphabetically by tag's name", async function (assert) {
    await visit("/");

    const tagSectionLinks = queryAll(
      ".sidebar-section-tags .sidebar-section-link:not(.sidebar-section-link-all-tags)"
    );

    const tagNames = [...tagSectionLinks].map((tagSectionLink) =>
      tagSectionLink.textContent.trim()
    );

    assert.deepEqual(
      tagNames,
      ["tag1", "tag2", "tag3", "tag4"],
      "tag section links are displayed in the right order"
    );
  });

  test("tag section links for user", async function (assert) {
    await visit("/");

    assert.strictEqual(
      count(
        ".sidebar-section-tags .sidebar-section-link:not(.sidebar-section-link-all-tags)"
      ),
      4,
      "4 section links under the section"
    );

    assert.strictEqual(
      query(".sidebar-section-link[data-tag-name=tag1]").textContent.trim(),
      "tag1",
      "displays the tag1 name for the link text"
    );

    assert.strictEqual(
      query(".sidebar-section-link[data-tag-name=tag2]").textContent.trim(),
      "tag2",
      "displays the tag2 name for the link text"
    );

    assert.strictEqual(
      query(".sidebar-section-link[data-tag-name=tag3]").textContent.trim(),
      "tag3",
      "displays the tag3 name for the link text"
    );

    await click(".sidebar-section-link[data-tag-name=tag1]");

    assert.strictEqual(
      currentURL(),
      "/tag/tag1",
      "it should transition to tag1's topics discovery page"
    );

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link[data-tag-name=tag1].active`),
      "the tag1 section link is marked as active"
    );

    await click(".sidebar-section-link[data-tag-name=tag2]");

    assert.strictEqual(
      currentURL(),
      "/tag/tag2",
      "it should transition to tag2's topics discovery page"
    );

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link[data-tag-name=tag2].active`),
      "the tag2 section link is marked as active"
    );
  });

  test("clicking tag section links - sidebar_list_destination set to unread/new and no unread or new topics", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
    });

    await visit("/");
    await click(".sidebar-section-link[data-tag-name=tag1]");

    assert.strictEqual(
      currentURL(),
      "/tag/tag1",
      "it should transition to tag1's topics discovery page"
    );

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link[data-tag-name=tag1].active`),
      "the tag1 section link is marked as active"
    );
  });

  test("clicking tag section links - sidebar_list_destination set to unread/new with new topics", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
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
    await click(".sidebar-section-link[data-tag-name=tag1]");

    assert.strictEqual(
      currentURL(),
      "/tag/tag1/l/new",
      "it should transition to tag1's topics new page"
    );

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link[data-tag-name=tag1].active`),
      "the tag1 section link is marked as active"
    );
  });

  test("clicking tag section links - sidebar_list_destination set to unread/new with unread topics", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
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
    await click(".sidebar-section-link[data-tag-name=tag1]");

    assert.strictEqual(
      currentURL(),
      "/tag/tag1/l/unread",
      "it should transition to tag1's topics unread page"
    );

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link[data-tag-name=tag1].active`),
      "the tag1 section link is marked as active"
    );
  });

  test("private message tag section links for user", async function (assert) {
    await visit("/");

    await click(".sidebar-section-link[data-tag-name=tag4]");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/messages/tags/tag4",
      "it should transition to user's private message tag4 tag page"
    );

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link[data-tag-name=tag4].active`),
      "the tag4 section link is marked as active"
    );
  });

  test("visiting tag discovery top route", async function (assert) {
    await visit(`/tag/tag1/l/top`);

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(".sidebar-section-link[data-tag-name=tag1].active"),
      "the tag1 section link is marked as active for the top route"
    );
  });

  test("visiting tag discovery new ", async function (assert) {
    await visit(`/tag/tag1/l/new`);

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(".sidebar-section-link[data-tag-name=tag1].active"),
      "the tag1 section link is marked as active for the new route"
    );
  });

  test("visiting tag discovery unread route", async function (assert) {
    await visit(`/tag/tag1/l/unread`);

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(".sidebar-section-link[data-tag-name=tag1].active"),
      "the tag1 section link is marked as active for the unread route"
    );
  });

  test("show suffix indicator for new content on tag section links", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "default",
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

    assert.ok(
      exists(
        `.sidebar-section-link[data-tag-name=tag1] .sidebar-section-link-suffix`
      ),
      "shows suffix indicator for new content on tag1 link"
    );

    assert.ok(
      exists(
        `.sidebar-section-link[data-tag-name=tag2] .sidebar-section-link-suffix`
      ),
      "shows suffix indicator for new content on tag2 link"
    );

    assert.ok(
      !exists(
        `.sidebar-section-link[data-tag-name=tag3] .sidebar-section-link-suffix`
      ),
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

    assert.ok(
      exists(
        `.sidebar-section-link[data-tag-name=tag1] .sidebar-section-link-suffix`
      ),
      "shows suffix indicator for new topic on tag1 link"
    );

    await publishToMessageBus("/unread", {
      topic_id: 1,
      message_type: "read",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 1,
      },
    });

    assert.ok(
      !exists(
        `.sidebar-section-link[data-tag-name=tag1] .sidebar-section-link-suffix`
      ),
      "hides suffix indicator for tag1 section link"
    );
  });

  test("new and unread count for tag section links", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
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
        `.sidebar-section-link[data-tag-name=tag1] .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.unread_count", { count: 1 }),
      `displays 1 unread count for tag1 section link`
    );

    assert.strictEqual(
      query(
        `.sidebar-section-link[data-tag-name=tag2] .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.unread_count", { count: 1 }),
      `displays 1 unread count for tag2 section link`
    );

    assert.ok(
      !exists(
        `.sidebar-section-link[data-tag-name=tag3] .sidebar-section-link-content-badge`
      ),
      "does not display any badge for tag3 section link"
    );

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
        `.sidebar-section-link[data-tag-name=tag1] .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.new_count", { count: 1 }),
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

    assert.ok(
      !exists(
        `.sidebar-section-link[data-tag-name=tag1] .sidebar-section-link-content-badge`
      ),
      `does not display any badge tag1 section link`
    );
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
    updateCurrentUser({ admin: true });

    await visit("/");

    assert.ok(
      exists(".sidebar-section-link-configure-default-sidebar-tags"),
      "section link to configure default sidebar tags is shown"
    );

    await click(".sidebar-section-link-configure-default-sidebar-tags");

    assert.strictEqual(
      currentURL(),
      "/admin/site_settings/category/all_results?filter=default_sidebar_tags",
      "it links to the admin site settings page correctly"
    );
  });
});

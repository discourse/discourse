import I18n from "I18n";
import { test } from "qunit";
import { click, currentURL, settled, visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  exists,
  publishToMessageBus,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

import { undockSidebar } from "discourse/tests/helpers/sidebar-helpers";

import discoveryFixture from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Sidebar - Tags section - tagging disabled", function (needs) {
  needs.settings({
    tagging_enabled: false,
  });

  needs.user({ experimental_sidebar_enabled: true });

  test("tags section is not shown", async function (assert) {
    await visit("/");

    assert.ok(
      !exists(".sidebar-section-tags"),
      "does not display the tags section"
    );
  });
});

acceptance("Sidebar - Tags section", function (needs) {
  needs.settings({
    tagging_enabled: true,
  });

  needs.user({
    experimental_sidebar_enabled: true,
    tracked_tags: ["tag1"],
    watched_tags: ["tag2", "tag3"],
    watching_first_post_tags: [],
    sidebar_tag_names: ["tag1", "tag2", "tag3"],
  });

  needs.pretender((server, helper) => {
    server.get("/tag/:tagId/notifications", (request) => {
      return helper.response({
        tag_notification: { id: request.params.tagId },
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

  test("clicking on section header link", async function (assert) {
    await visit("/");
    await click(".sidebar-section-tags .sidebar-section-header-link");

    assert.strictEqual(
      currentURL(),
      "/tags",
      "it should transition to the tags page"
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

  test("section content when user has not added any tags", async function (assert) {
    updateCurrentUser({
      sidebar_tag_names: [],
    });

    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section-tags .sidebar-section-message"
      ).textContent.trim(),
      `${I18n.t("sidebar.sections.tags.none")} ${I18n.t(
        "sidebar.sections.tags.click_to_get_started"
      )}`,
      "the no tags message is displayed"
    );
  });

  test("tag section links for user", async function (assert) {
    await visit("/");

    assert.strictEqual(
      count(".sidebar-section-tags .sidebar-section-link"),
      3,
      "3 section links under the section"
    );

    assert.strictEqual(
      query(".sidebar-section-link-tag1").textContent.trim(),
      "tag1",
      "displays the tag1 name for the link text"
    );

    assert.strictEqual(
      query(".sidebar-section-link-tag2").textContent.trim(),
      "tag2",
      "displays the tag2 name for the link text"
    );

    assert.strictEqual(
      query(".sidebar-section-link-tag3").textContent.trim(),
      "tag3",
      "displays the tag3 name for the link text"
    );

    await click(".sidebar-section-link-tag1");

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
      exists(`.sidebar-section-link-tag1.active`),
      "the tag1 section link is marked as active"
    );

    await click(".sidebar-section-link-tag2");

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
      exists(`.sidebar-section-link-tag2.active`),
      "the tag2 section link is marked as active"
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
      exists(".sidebar-section-link-tag1.active"),
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
      exists(".sidebar-section-link-tag1.active"),
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
      exists(".sidebar-section-link-tag1.active"),
      "the tag1 section link is marked as active for the unread route"
    );
  });

  test("new and unread count for tag section links", async function (assert) {
    this.container.lookup("topic-tracking-state:main").loadStates([
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
        `.sidebar-section-link-tag1 .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.unread_count", { count: 1 }),
      `displays 1 unread count for tag1 section link`
    );

    assert.strictEqual(
      query(
        `.sidebar-section-link-tag2 .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.unread_count", { count: 1 }),
      `displays 1 unread count for tag2 section link`
    );

    assert.ok(
      !exists(`.sidebar-section-link-tag3 .sidebar-section-link-content-badge`),
      "does not display any badge for tag3 section link"
    );

    publishToMessageBus("/unread", {
      topic_id: 2,
      message_type: "read",
      payload: {
        last_read_post_number: 12,
        highest_post_number: 12,
      },
    });

    await settled();

    assert.strictEqual(
      query(
        `.sidebar-section-link-tag1 .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.new_count", { count: 1 }),
      `displays 1 new count for tag1 section link`
    );

    publishToMessageBus("/unread", {
      topic_id: 1,
      message_type: "read",
      payload: {
        last_read_post_number: 1,
        highest_post_number: 1,
      },
    });

    await settled();

    assert.ok(
      !exists(`.sidebar-section-link-tag1 .sidebar-section-link-content-badge`),
      `does not display any badge tag1 section link`
    );
  });

  test("cleans up topic tracking state state changed callbacks when section is destroyed", async function (assert) {
    await visit("/");

    const topicTrackingState = this.container.lookup(
      "topic-tracking-state:main"
    );

    const initialCallbackCount = Object.keys(
      topicTrackingState.stateChangeCallbacks
    ).length;

    await undockSidebar();

    assert.ok(
      Object.keys(topicTrackingState.stateChangeCallbacks).length <
        initialCallbackCount
    );
  });
});

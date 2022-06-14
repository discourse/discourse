import I18n from "I18n";

import { click, currentURL, settled, visit } from "@ember/test-helpers";

import {
  acceptance,
  conditionalTest,
  exists,
  publishToMessageBus,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { isLegacyEmber } from "discourse-common/config/environment";
import discoveryFixture from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { NotificationLevels } from "discourse/lib/notification-levels";

acceptance("Sidebar - Tags section - tagging disabled", function (needs) {
  needs.settings({
    tagging_enabled: false,
  });

  needs.user({ experimental_sidebar_enabled: true });

  conditionalTest(
    "tags section is not shown",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      assert.ok(
        !exists(".sidebar-section-tags"),
        "does not display the tags section"
      );
    }
  );
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

    server.put("/tag/:tagId/notifications", (request) => {
      return helper.response({
        watched_tags: [],
        watching_first_post_tags: [],
        regular_tags: [request.params.tagId],
        tracked_tags: [],
        muted_tags: [],
      });
    });
  });

  conditionalTest(
    "clicking on section header link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");
      await click(".sidebar-section-tags .sidebar-section-header-link");

      assert.strictEqual(
        currentURL(),
        "/tags",
        "it should transition to the tags page"
      );
    }
  );

  conditionalTest(
    "section content when user does not have any tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      updateCurrentUser({
        tracked_tags: [],
        watched_tags: [],
        watching_first_post_tags: [],
      });

      await visit("/");

      assert.strictEqual(
        query(
          ".sidebar-section-tags .sidebar-section-message"
        ).textContent.trim(),
        I18n.t("sidebar.sections.tags.no_tracked_tags"),
        "the no tracked tags message is displayed"
      );
    }
  );

  conditionalTest(
    "tag section links for tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link").length,
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
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
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
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(`.sidebar-section-link-tag2.active`),
        "the tag2 section link is marked as active"
      );
    }
  );

  conditionalTest(
    "visiting tag discovery top route for tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      await visit(`/tag/tag1/l/top`);

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-link-tag1.active"),
        "the tag1 section link is marked as active for the top route"
      );
    }
  );

  conditionalTest(
    "visiting tag discovery new route for tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      await visit(`/tag/tag1/l/new`);

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-link-tag1.active"),
        "the tag1 section link is marked as active for the new route"
      );
    }
  );

  conditionalTest(
    "visiting tag discovery unread route for tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      await visit(`/tag/tag1/l/unread`);

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-link-tag1.active"),
        "the tag1 section link is marked as active for the unread route"
      );
    }
  );

  conditionalTest(
    "new and unread count for tag section links",
    !isLegacyEmber(),
    async function (assert) {
      this.container.lookup("topic-tracking-state:main").loadStates([
        {
          topic_id: 1,
          highest_post_number: 1,
          last_read_post_number: null,
          created_at: "2022-05-11T03:09:31.959Z",
          category_id: 1,
          notification_level: null,
          created_in_new_period: true,
          unread_not_too_old: true,
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
          unread_not_too_old: true,
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
          unread_not_too_old: true,
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
          unread_not_too_old: true,
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
        !exists(
          `.sidebar-section-link-tag3 .sidebar-section-link-content-badge`
        ),
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
        !exists(
          `.sidebar-section-link-tag1 .sidebar-section-link-content-badge`
        ),
        `does not display any badge tag1 section link`
      );
    }
  );

  conditionalTest(
    "cleans up topic tracking state state changed callbacks when section is destroyed",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      const topicTrackingState = this.container.lookup(
        "topic-tracking-state:main"
      );

      const initialCallbackCount = Object.keys(
        topicTrackingState.stateChangeCallbacks
      ).length;

      await click(".header-sidebar-toggle .btn");
      await click(".header-sidebar-toggle .btn");

      assert.strictEqual(
        Object.keys(topicTrackingState.stateChangeCallbacks).length,
        initialCallbackCount
      );
    }
  );

  conditionalTest(
    "updating tags notification levels",
    !isLegacyEmber(),
    async function (assert) {
      await visit(`/tag/tag1/l/unread`);

      const notificationLevelsDropdown = selectKit(".notifications-button");

      await notificationLevelsDropdown.expand();

      await notificationLevelsDropdown.selectRowByValue(
        NotificationLevels.REGULAR
      );

      assert.ok(
        !exists(".sidebar-section-tags .sidebar-section-link-tag1"),
        "tag1 section link is removed from sidebar"
      );
    }
  );
});

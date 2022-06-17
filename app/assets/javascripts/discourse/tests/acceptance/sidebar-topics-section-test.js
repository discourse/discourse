import { click, currentURL, settled, visit } from "@ember/test-helpers";

import {
  acceptance,
  conditionalTest,
  exists,
  loggedInUser,
  publishToMessageBus,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { isLegacyEmber } from "discourse-common/config/environment";
import topicFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import Site from "discourse/models/site";
import { NotificationLevels } from "discourse/lib/notification-levels";

acceptance("Sidebar - Topics Section", function (needs) {
  needs.user({
    experimental_sidebar_enabled: true,
    tracked_tags: ["tag1"],
    watched_tags: ["tag2"],
    watching_first_post_tags: ["tag3"],
  });

  needs.pretender((server, helper) => {
    server.get("/new.json", () => {
      return helper.response(cloneJSON(topicFixtures["/latest.json"]));
    });

    server.get("/unread.json", () => {
      return helper.response(cloneJSON(topicFixtures["/latest.json"]));
    });

    server.get("/top.json", () => {
      return helper.response(cloneJSON(topicFixtures["/latest.json"]));
    });
  });

  conditionalTest(
    "clicking on section header button",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");
      await click(".sidebar-section-topics .sidebar-section-header-button");

      assert.ok(exists("#reply-control"), "it opens the composer");
    }
  );

  conditionalTest(
    "clicking on section header button while viewing a category",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/c/bug");
      await click(".sidebar-section-topics .sidebar-section-header-button");

      assert.ok(exists("#reply-control"), "it opens the composer");

      assert.strictEqual(
        query(".category-input .selected-name .category-name").textContent,
        "bug",
        "the current category is prefilled in the composer input"
      );
    }
  );

  conditionalTest(
    "clicking on section caret button",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-content"),
        "shows content section"
      );

      await click(".sidebar-section-topics .sidebar-section-header-caret");

      assert.ok(
        !exists(".sidebar-section-topics .sidebar-section-content"),
        "hides content section"
      );

      await click(".sidebar-section-topics .sidebar-section-header-caret");

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-content"),
        "shows content section"
      );
    }
  );

  conditionalTest(
    "clicking on section header link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/t/280");
      await click(".sidebar-section-topics .sidebar-section-header-link");

      assert.strictEqual(
        currentURL(),
        "/latest",
        "it should transistion to the homepage"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(
          ".sidebar-section-topics .sidebar-section-link-everything.active"
        ),
        "the everything link is marked as active"
      );
    }
  );

  conditionalTest(
    "clicking on everything link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/t/280");
      await click(".sidebar-section-topics .sidebar-section-link-everything");

      assert.strictEqual(
        currentURL(),
        "/latest",
        "it should transistion to the latest page"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(
          ".sidebar-section-topics .sidebar-section-link-everything.active"
        ),
        "the everything link is marked as active"
      );
    }
  );

  conditionalTest(
    "clicking on tracked link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/t/280");
      await click(".sidebar-section-topics .sidebar-section-link-tracked");

      assert.strictEqual(
        currentURL(),
        "/latest?f=tracked",
        "it should transistion to the tracked url"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-link-tracked.active"),
        "the tracked link is marked as active"
      );
    }
  );

  conditionalTest(
    "clicking on bookmarked link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/t/280");
      await click(".sidebar-section-topics .sidebar-section-link-bookmarked");

      assert.strictEqual(
        currentURL(),
        `/u/${loggedInUser().username}/activity/bookmarks`,
        "it should transistion to the bookmarked url"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(
          ".sidebar-section-topics .sidebar-section-link-bookmarked.active"
        ),
        "the bookmarked link is marked as active"
      );
    }
  );

  conditionalTest(
    "clicking on my posts link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/t/280");
      await click(".sidebar-section-topics .sidebar-section-link-my-posts");

      assert.strictEqual(
        currentURL(),
        `/u/${loggedInUser().username}/activity`,
        "it should transistion to the user's activity url"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-link-my-posts.active"),
        "the my posts link is marked as active"
      );

      await visit(`/u/${loggedInUser().username}/activity/drafts`);

      assert.notOk(
        exists(".sidebar-section-topics .sidebar-section-link-my-posts.active"),
        "the my posts link is not marked as active when user has no drafts and visiting the user activity drafts URL"
      );
    }
  );

  conditionalTest(
    "clicking on my posts link when user has a draft",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/t/280");

      publishToMessageBus(`/user-drafts/${loggedInUser().id}`, {
        draft_count: 1,
      });

      await settled();

      await click(".sidebar-section-topics .sidebar-section-link-my-posts");

      assert.strictEqual(
        currentURL(),
        `/u/${loggedInUser().username}/activity/drafts`,
        "it transistions to the user's activity drafts url"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-link-my-posts.active"),
        "the my posts link is marked as active"
      );

      await visit(`/u/${loggedInUser().username}/activity`);

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-link-my-posts.active"),
        "the my posts link is marked as active"
      );
    }
  );

  conditionalTest(
    "visiting top route",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/top");

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(
          ".sidebar-section-topics .sidebar-section-link-everything.active"
        ),
        "the everything link is marked as active"
      );
    }
  );

  conditionalTest(
    "visiting unread route",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/unread");

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(
          ".sidebar-section-topics .sidebar-section-link-everything.active"
        ),
        "the everything link is marked as active"
      );
    }
  );

  conditionalTest(
    "visiting new route",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/new");

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(
          ".sidebar-section-topics .sidebar-section-link-everything.active"
        ),
        "the everything link is marked as active"
      );
    }
  );

  conditionalTest(
    "new and unread count for everything link",
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
        },
      ]);

      await visit("/");

      assert.strictEqual(
        query(
          ".sidebar-section-link-everything .sidebar-section-link-content-badge"
        ).textContent.trim(),
        "3 unread",
        "it displays the right unread count"
      );

      assert.ok(
        query(".sidebar-section-link-everything").href.endsWith("/unread"),
        "it links to unread filter"
      );

      // simulate reading topic 2
      publishToMessageBus("/unread", {
        topic_id: 2,
        message_type: "read",
        payload: {
          last_read_post_number: 12,
          highest_post_number: 12,
          notification_level: 2,
        },
      });

      await settled();

      assert.strictEqual(
        query(
          ".sidebar-section-link-everything .sidebar-section-link-content-badge"
        ).textContent.trim(),
        "2 unread",
        "it updates the unread count"
      );

      // simulate reading topic 3
      publishToMessageBus("/unread", {
        topic_id: 3,
        message_type: "read",
        payload: {
          last_read_post_number: 15,
          highest_post_number: 15,
          notification_level: 2,
        },
      });

      // simulate reading topic 4
      publishToMessageBus("/unread", {
        topic_id: 4,
        message_type: "read",
        payload: {
          last_read_post_number: 17,
          highest_post_number: 17,
          notification_level: 2,
        },
      });

      await settled();

      assert.strictEqual(
        query(
          ".sidebar-section-link-everything .sidebar-section-link-content-badge"
        ).textContent.trim(),
        "1 new",
        "it displays the new count once there are no unread topics"
      );

      assert.ok(
        query(".sidebar-section-link-everything").href.endsWith("/new"),
        "it links to new filter"
      );

      publishToMessageBus("/unread", {
        topic_id: 1,
        message_type: "read",
        payload: {
          last_read_post_number: 1,
          highest_post_number: 1,
          notification_level: 2,
        },
      });

      await settled();

      assert.ok(
        !exists(
          ".sidebar-section-link-everything .sidebar-section-link-content-badge"
        ),
        "it removes new count once there are no new topics"
      );

      assert.ok(
        query(".sidebar-section-link-everything").href.endsWith("/latest"),
        "it links to latest filter"
      );
    }
  );

  conditionalTest(
    "visiting top route with tracked filter",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/top?f=tracked");

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-link-tracked.active"),
        "the tracked link is marked as active"
      );
    }
  );

  conditionalTest(
    "visiting unread route with tracked filter",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/unread?f=tracked");

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-link-tracked.active"),
        "the tracked link is marked as active"
      );
    }
  );

  conditionalTest(
    "visiting new route with tracked filter",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/new?f=tracked");

      assert.strictEqual(
        queryAll(".sidebar-section-topics .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-topics .sidebar-section-link-tracked.active"),
        "the tracked link is marked as active"
      );
    }
  );

  conditionalTest(
    "new and unread count for tracked link",
    !isLegacyEmber(),
    async function (assert) {
      const categories = Site.current().categories;

      // Category id 1001 has two subcategories
      const category = categories.find((c) => c.id === 1001);
      category.set("notification_level", NotificationLevels.TRACKING);

      this.container.lookup("topic-tracking-state:main").loadStates([
        {
          topic_id: 1,
          highest_post_number: 1,
          last_read_post_number: null,
          created_at: "2022-05-11T03:09:31.959Z",
          category_id: category.id,
          notification_level: NotificationLevels.TRACKING,
          created_in_new_period: true,
          unread_not_too_old: true,
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
          unread_not_too_old: true,
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
          unread_not_too_old: true,
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
          unread_not_too_old: true,
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
          unread_not_too_old: true,
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
          unread_not_too_old: true,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
          tags: ["tag3"],
        },
      ]);

      await visit("/");

      assert.strictEqual(
        query(
          ".sidebar-section-link-tracked .sidebar-section-link-content-badge"
        ).textContent.trim(),
        "3 unread",
        "it displays the right unread count"
      );

      assert.ok(
        query(".sidebar-section-link-tracked").href.endsWith(
          "/unread?f=tracked"
        ),
        "it links to unread url with tracked filter"
      );

      // simulate reading topic id 2
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
          ".sidebar-section-link-tracked .sidebar-section-link-content-badge"
        ).textContent.trim(),
        "2 unread",
        "it updates the unread count"
      );

      // simulate reading topic id 3
      publishToMessageBus("/unread", {
        topic_id: 3,
        message_type: "read",
        payload: {
          last_read_post_number: 17,
          highest_post_number: 17,
        },
      });

      // simulate reading topic id 6
      publishToMessageBus("/unread", {
        topic_id: 6,
        message_type: "read",
        payload: {
          last_read_post_number: 17,
          highest_post_number: 17,
        },
      });

      assert.strictEqual(
        query(
          ".sidebar-section-link-tracked .sidebar-section-link-content-badge"
        ).textContent.trim(),
        "1 new",
        "it displays the new count once there are no tracked unread topics"
      );

      assert.ok(
        query(".sidebar-section-link-tracked").href.endsWith("/new?f=tracked"),
        "it links to new url with tracked filter"
      );

      // simulate reading topic id 1
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
          ".sidebar-section-link-tracked .sidebar-section-link-content-badge"
        ),
        "it removes new count once there are no tracked new topics"
      );

      assert.ok(
        query(".sidebar-section-link-tracked").href.endsWith(
          "/latest?f=tracked"
        ),
        "it links to latest url with tracked filter"
      );
    }
  );

  conditionalTest(
    "adding section link via plugin API with Object",
    !isLegacyEmber(),
    async function (assert) {
      withPluginApi("1.2.0", (api) => {
        api.addTopicsSectionLink({
          name: "unread",
          route: "discovery.unread",
          text: "unread topics",
          title: "List of unread topics",
        });
      });

      await visit("/");

      assert.strictEqual(
        query(".sidebar-section-link-unread").textContent.trim(),
        "unread topics",
        "displays the right text for the link"
      );

      assert.strictEqual(
        query(".sidebar-section-link-unread").title,
        "List of unread topics",
        "displays the right title for the link"
      );

      await click(".sidebar-section-link-unread");

      assert.strictEqual(currentURL(), "/unread", "links to the right URL");
    }
  );

  conditionalTest(
    "adding section link via plugin API with callback function",
    !isLegacyEmber(),
    async function (assert) {
      withPluginApi("1.2.0", (api) => {
        api.addTopicsSectionLink((baseSectionLink) => {
          return class CustomSectionLink extends baseSectionLink {
            get name() {
              return "user-summary";
            }

            get route() {
              return "user.summary";
            }

            get model() {
              return this.currentUser;
            }

            get title() {
              return `${this.currentUser.username} summary`;
            }

            get text() {
              return "my summary";
            }
          };
        });
      });

      await visit("/");
      await click(".sidebar-section-link-user-summary");

      assert.strictEqual(
        currentURL(),
        "/u/eviltrout/summary",
        "links to the right URL"
      );

      assert.strictEqual(
        query(".sidebar-section-link-user-summary").textContent.trim(),
        "my summary",
        "displays the right text for the link"
      );

      assert.strictEqual(
        query(".sidebar-section-link-user-summary").title,
        "eviltrout summary",
        "displays the right title for the link"
      );
    }
  );

  conditionalTest(
    "clean up topic tracking state state changed callbacks when section is destroyed",
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
});

import I18n from "I18n";

import { click, currentURL, settled, visit } from "@ember/test-helpers";

import {
  acceptance,
  conditionalTest,
  exists,
  publishToMessageBus,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { isLegacyEmber } from "discourse-common/config/environment";
import Site from "discourse/models/site";
import { NotificationLevels } from "discourse/lib/notification-levels";
import discoveryFixture from "discourse/tests/fixtures/discovery-fixtures";
import categoryFixture from "discourse/tests/fixtures/category-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

acceptance(
  "Sidebar - Categories Section - suppress_uncategorized_badge enabled",
  function (needs) {
    needs.settings({
      suppress_uncategorized_badge: true,
    });

    needs.user({ experimental_sidebar_enabled: true });

    conditionalTest(
      "uncategorized category is not shown",
      !isLegacyEmber(),
      async function (assert) {
        const categories = Site.current().categories;
        const category1 = categories[0];

        const uncategorizedCategory = categories.find((category) => {
          return category.id === Site.current().uncategorized_category_id;
        });

        category1.set("notification_level", NotificationLevels.TRACKING);

        uncategorizedCategory.set(
          "notification_level",
          NotificationLevels.TRACKING
        );

        await visit("/");

        assert.strictEqual(
          queryAll(".sidebar-section-categories .sidebar-section-link").length,
          1,
          "there should only be one section link under the section"
        );

        assert.ok(
          exists(`.sidebar-section-link-${category1.slug}`),
          `only the ${category1.slug} section link is shown`
        );
      }
    );
  }
);

acceptance("Sidebar - Categories Section", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });

  needs.settings({
    suppress_uncategorized_badge: false,
  });

  needs.pretender((server, helper) => {
    ["latest", "top", "new", "unread"].forEach((type) => {
      server.get(`/c/:categorySlug/:categoryId/l/${type}.json`, () => {
        return helper.response(
          cloneJSON(discoveryFixture["/c/bug/1/l/latest.json"])
        );
      });
    });

    server.get("/c/:categorySlug/:categoryId/find_by_slug.json", () => {
      return helper.response(cloneJSON(categoryFixture["/c/1/show.json"]));
    });

    server.post("/category/:categoryId/notifications", () => {
      return helper.response({});
    });
  });

  const setupTrackedCategories = function () {
    const categories = Site.current().categories;
    const category1 = categories[0];
    const category2 = categories[1];
    category1.set("notification_level", NotificationLevels.TRACKING);
    category2.set("notification_level", NotificationLevels.TRACKING);

    return { category1, category2 };
  };

  conditionalTest(
    "clicking on section header link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/t/280");
      await click(".sidebar-section-categories .sidebar-section-header-link");

      assert.strictEqual(
        currentURL(),
        "/categories",
        "it should transition to the categories page"
      );
    }
  );

  conditionalTest(
    "category section links when user does not have any tracked categories",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      assert.strictEqual(
        query(".sidebar-section-message").textContent.trim(),
        I18n.t("sidebar.sections.categories.no_tracked_categories"),
        "the no tracked categories message is displayed"
      );
    }
  );

  conditionalTest(
    "uncategorized category is shown when tracked",
    !isLegacyEmber(),
    async function (assert) {
      const categories = Site.current().categories;

      const uncategorizedCategory = categories.find((category) => {
        return category.id === Site.current().uncategorized_category_id;
      });

      uncategorizedCategory.set(
        "notification_level",
        NotificationLevels.TRACKING
      );

      await visit("/");

      assert.ok(
        exists(`.sidebar-section-link-${uncategorizedCategory.slug}`),
        `displays the section link for ${uncategorizedCategory.slug} category`
      );
    }
  );

  conditionalTest(
    "category section links for tracked categories",
    !isLegacyEmber(),
    async function (assert) {
      const { category1, category2 } = setupTrackedCategories();

      await visit("/");

      assert.strictEqual(
        queryAll(".sidebar-section-categories .sidebar-section-link").length,
        2,
        "there should only be two section link under the section"
      );

      assert.ok(
        exists(`.sidebar-section-link-${category1.slug} .badge-category`),
        "category1 section link is rendered with category badge"
      );

      assert.strictEqual(
        query(`.sidebar-section-link-${category1.slug}`).textContent.trim(),
        category1.name,
        "displays category1's name for the link text"
      );

      await click(`.sidebar-section-link-${category1.slug}`);

      assert.strictEqual(
        currentURL(),
        `/c/${category1.slug}/${category1.id}/l/latest`,
        "it should transition to the category1's discovery page"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-categories .sidebar-section-link.active")
          .length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(`.sidebar-section-link-${category1.slug}.active`),
        "the category1 section link is marked as active"
      );

      await click(`.sidebar-section-link-${category2.slug}`);

      assert.strictEqual(
        currentURL(),
        `/c/${category2.slug}/${category2.id}/l/latest`,
        "it should transition to the category2's discovery page"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-categories .sidebar-section-link.active")
          .length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(`.sidebar-section-link-${category2.slug}.active`),
        "the category2 section link is marked as active"
      );
    }
  );

  conditionalTest(
    "visiting category discovery new route for tracked categories",
    !isLegacyEmber(),
    async function (assert) {
      const { category1 } = setupTrackedCategories();

      await visit(`/c/${category1.slug}/${category1.id}/l/new`);

      assert.strictEqual(
        queryAll(".sidebar-section-categories .sidebar-section-link.active")
          .length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(`.sidebar-section-link-${category1.slug}.active`),
        "the category1 section link is marked as active for the new route"
      );
    }
  );

  conditionalTest(
    "visiting category discovery unread route for tracked categories",
    !isLegacyEmber(),
    async function (assert) {
      const { category1 } = setupTrackedCategories();

      await visit(`/c/${category1.slug}/${category1.id}/l/unread`);

      assert.strictEqual(
        queryAll(".sidebar-section-categories .sidebar-section-link.active")
          .length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(`.sidebar-section-link-${category1.slug}.active`),
        "the category1 section link is marked as active for the unread route"
      );
    }
  );

  conditionalTest(
    "visiting category discovery top route for tracked categories",
    !isLegacyEmber(),
    async function (assert) {
      const { category1 } = setupTrackedCategories();

      await visit(`/c/${category1.slug}/${category1.id}/l/top`);

      assert.strictEqual(
        queryAll(".sidebar-section-categories .sidebar-section-link.active")
          .length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(`.sidebar-section-link-${category1.slug}.active`),
        "the category1 section link is marked as active for the top route"
      );
    }
  );

  conditionalTest(
    "updating category notification level",
    !isLegacyEmber(),
    async function (assert) {
      const { category1, category2 } = setupTrackedCategories();

      await visit(`/c/${category1.slug}/${category1.id}/l/top`);

      assert.ok(
        exists(`.sidebar-section-link-${category1.slug}`),
        `has ${category1.name} section link in sidebar`
      );

      assert.ok(
        exists(`.sidebar-section-link-${category2.slug}`),
        `has ${category2.name} section link in sidebar`
      );

      const notificationLevelsDropdown = selectKit(".notifications-button");

      await notificationLevelsDropdown.expand();

      await notificationLevelsDropdown.selectRowByValue(
        NotificationLevels.REGULAR
      );

      assert.ok(
        !exists(`.sidebar-section-link-${category1.slug}`),
        `does not have ${category1.name} section link in sidebar`
      );

      assert.ok(
        exists(`.sidebar-section-link-${category2.slug}`),
        `has ${category2.name} section link in sidebar`
      );

      await notificationLevelsDropdown.expand();

      await notificationLevelsDropdown.selectRowByValue(
        NotificationLevels.TRACKING
      );

      assert.ok(
        exists(`.sidebar-section-link-${category1.slug}`),
        `has ${category1.name} section link in sidebar`
      );

      assert.ok(
        exists(`.sidebar-section-link-${category2.slug}`),
        `has ${category2.name} section link in sidebar`
      );
    }
  );

  conditionalTest(
    "new and unread count for categories link",
    !isLegacyEmber(),
    async function (assert) {
      const { category1, category2 } = setupTrackedCategories();

      this.container.lookup("topic-tracking-state:main").loadStates([
        {
          topic_id: 1,
          highest_post_number: 1,
          last_read_post_number: null,
          created_at: "2022-05-11T03:09:31.959Z",
          category_id: category1.id,
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
          category_id: category1.id,
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
          category_id: category2.id,
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
          category_id: category2.id,
          notification_level: 2,
          created_in_new_period: false,
          unread_not_too_old: true,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
      ]);

      await visit("/");

      assert.strictEqual(
        query(
          `.sidebar-section-link-${category1.slug} .sidebar-section-link-content-badge`
        ).textContent.trim(),
        I18n.t("sidebar.unread_count", { count: 1 }),
        `displays 1 unread count for ${category1.slug} section link`
      );

      assert.strictEqual(
        query(
          `.sidebar-section-link-${category2.slug} .sidebar-section-link-content-badge`
        ).textContent.trim(),
        I18n.t("sidebar.unread_count", { count: 2 }),
        `displays 2 unread count for ${category2.slug} section link`
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
          `.sidebar-section-link-${category1.slug} .sidebar-section-link-content-badge`
        ).textContent.trim(),
        I18n.t("sidebar.new_count", { count: 1 }),
        `displays 1 new count for ${category1.slug} section link`
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
          `.sidebar-section-link-${category1.slug} .sidebar-section-link-content-badge`
        ),
        `does not display any badge ${category1.slug} section link`
      );

      publishToMessageBus("/unread", {
        topic_id: 3,
        message_type: "read",
        payload: {
          last_read_post_number: 15,
          highest_post_number: 15,
        },
      });

      await settled();

      assert.strictEqual(
        query(
          `.sidebar-section-link-${category2.slug} .sidebar-section-link-content-badge`
        ).textContent.trim(),
        I18n.t("sidebar.unread_count", { count: 1 }),
        `displays 1 unread count for ${category2.slug} section link`
      );
    }
  );

  conditionalTest(
    "clean up topic tracking state state changed callbacks when section is destroyed",
    !isLegacyEmber(),
    async function (assert) {
      setupTrackedCategories();

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

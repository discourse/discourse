import I18n from "I18n";

import { click, currentURL, visit } from "@ember/test-helpers";

import {
  acceptance,
  conditionalTest,
  exists,
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

acceptance("Sidebar - Categories Section", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });

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
});

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
import Site from "discourse/models/site";
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

    test("uncategorized category is not shown", async function (assert) {
      const categories = Site.current().categories;
      const category1 = categories[0];

      const uncategorizedCategory = categories.find((category) => {
        return category.id === Site.current().uncategorized_category_id;
      });

      updateCurrentUser({
        sidebar_category_ids: [category1.id, uncategorizedCategory.id],
      });

      await visit("/");

      assert.strictEqual(
        count(".sidebar-section-categories .sidebar-section-link"),
        1,
        "there should only be one section link under the section"
      );

      assert.ok(
        exists(`.sidebar-section-link-${category1.slug}`),
        `only the ${category1.slug} section link is shown`
      );
    });
  }
);

acceptance("Sidebar - Categories Section", function (needs) {
  needs.user({
    experimental_sidebar_enabled: true,
    sidebar_category_ids: [],
    sidebar_tag_names: [],
  });

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
  });

  const setupUserSidebarCategories = function () {
    const categories = Site.current().categories;
    const category1 = categories[0];
    const category2 = categories[1];
    updateCurrentUser({ sidebar_category_ids: [category1.id, category2.id] });
    return { category1, category2 };
  };

  test("clicking on section header link", async function (assert) {
    await visit("/t/280");
    await click(".sidebar-section-categories .sidebar-section-header-link");

    assert.strictEqual(
      currentURL(),
      "/categories",
      "it should transition to the categories page"
    );
  });

  test("clicking on section header button", async function (assert) {
    await visit("/");
    await click(".sidebar-section-categories .sidebar-section-header-button");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/sidebar",
      "it should transition to user preferences sidebar page"
    );
  });

  test("category section links when user has not added any categories", async function (assert) {
    await visit("/");

    assert.ok(
      exists(".sidebar-section-message"),
      "the no categories message is displayed"
    );

    await click(".sidebar-section-message a");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/sidebar",
      "it should transition to user preferences sidebar page"
    );
  });

  test("uncategorized category is shown when added to sidebar", async function (assert) {
    const categories = Site.current().categories;

    const uncategorizedCategory = categories.find((category) => {
      return category.isUncategorizedCategory;
    });

    updateCurrentUser({ sidebar_category_ids: [uncategorizedCategory.id] });

    await visit("/");

    assert.ok(
      exists(`.sidebar-section-link-${uncategorizedCategory.slug}`),
      `displays the section link for ${uncategorizedCategory.slug} category`
    );
  });

  test("category section links uses the bullet style even when category_style site setting has been configured", async function (assert) {
    this.siteSettings.category_style = "box";
    const { category1 } = setupUserSidebarCategories();

    await visit("/");

    assert.ok(
      exists(
        `.sidebar-section-categories .sidebar-section-link-${category1.slug} .badge-wrapper.bullet`
      ),
      "category badge uses the bullet style"
    );
  });

  test("category section links", async function (assert) {
    const { category1, category2 } = setupUserSidebarCategories();

    await visit("/");

    assert.strictEqual(
      count(".sidebar-section-categories .sidebar-section-link"),
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
      count(".sidebar-section-categories .sidebar-section-link.active"),
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
      count(".sidebar-section-categories .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link-${category2.slug}.active`),
      "the category2 section link is marked as active"
    );
  });

  test("visiting category discovery new route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/l/new`);

    assert.strictEqual(
      count(".sidebar-section-categories .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link-${category1.slug}.active`),
      "the category1 section link is marked as active for the new route"
    );
  });

  test("visiting category discovery unread route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/l/unread`);

    assert.strictEqual(
      count(".sidebar-section-categories .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link-${category1.slug}.active`),
      "the category1 section link is marked as active for the unread route"
    );
  });

  test("visiting category discovery top route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/l/top`);

    assert.strictEqual(
      count(".sidebar-section-categories .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link-${category1.slug}.active`),
      "the category1 section link is marked as active for the top route"
    );
  });

  test("new and unread count for categories link", async function (assert) {
    const { category1, category2 } = setupUserSidebarCategories();

    this.container.lookup("topic-tracking-state:main").loadStates([
      {
        topic_id: 1,
        highest_post_number: 1,
        last_read_post_number: null,
        created_at: "2022-05-11T03:09:31.959Z",
        category_id: category1.id,
        notification_level: null,
        created_in_new_period: true,
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
  });

  test("clean up topic tracking state state changed callbacks when section is destroyed", async function (assert) {
    setupUserSidebarCategories();

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
  });
});

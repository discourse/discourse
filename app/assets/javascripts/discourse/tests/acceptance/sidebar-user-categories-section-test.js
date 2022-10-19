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

import Site from "discourse/models/site";
import discoveryFixture from "discourse/tests/fixtures/discovery-fixtures";
import categoryFixture from "discourse/tests/fixtures/category-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import { NotificationLevels } from "discourse/lib/notification-levels";

acceptance(
  "Sidebar - Logged on user - Categories Section - allow_uncategorized_topics disabled",
  function (needs) {
    needs.settings({
      allow_uncategorized_topics: false,
      enable_experimental_sidebar_hamburger: true,
      enable_sidebar: true,
    });

    needs.user({ admin: false });

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
        count(
          ".sidebar-section-categories .sidebar-section-link:not(.sidebar-section-link-all-categories)"
        ),
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

acceptance("Sidebar - Logged on user - Categories Section", function (needs) {
  needs.user({
    sidebar_category_ids: [],
    sidebar_tags: [],
    admin: false,
  });

  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
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

    server.get(`/c/:categorySlug/:categoryId/none/l/latest.json`, () => {
      return helper.response(
        cloneJSON(discoveryFixture["/c/bug/1/l/latest.json"])
      );
    });

    server.get("/c/:categorySlug/:categoryId/find_by_slug.json", () => {
      return helper.response(cloneJSON(categoryFixture["/c/1/show.json"]));
    });
  });

  const setupUserSidebarCategories = function () {
    const categories = Site.current().categories;
    const category1 = categories[0];
    const category2 = categories[1];
    const category3 = categories[5];
    const category4 = categories[24];

    updateCurrentUser({
      sidebar_category_ids: [
        category1.id,
        category2.id,
        category3.id,
        category4.id,
      ],
    });

    return { category1, category2, category3, category4 };
  };

  test("clicking on section header link", async function (assert) {
    setupUserSidebarCategories();

    await visit("/t/280");
    await click(".sidebar-section-categories .sidebar-section-header");

    assert.notOk(
      exists(".sidebar-section-categories .sidebar-section-content"),
      "hides the content of the section"
    );
  });

  test("clicking on section header button", async function (assert) {
    setupUserSidebarCategories();

    await visit("/");
    await click(".sidebar-section-categories .sidebar-section-header-button");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/sidebar",
      "it should transition to user preferences sidebar page"
    );
  });

  test("categories section is hidden when user has not added any categories and there are no default categories configured", async function (assert) {
    updateCurrentUser({ sidebar_category_ids: [] });

    await visit("/");

    assert.notOk(
      exists(".sidebar-section-categories"),
      "categories section is not shown"
    );
  });

  test("categories section is shown when user has not added any categories but default categories have been configured", async function (assert) {
    updateCurrentUser({ sidebar_category_ids: [] });
    const categories = Site.current().categories;
    this.siteSettings.default_sidebar_categories = `${categories[0].id}|${categories[1].id}`;

    await visit("/");

    assert.ok(
      exists(".sidebar-section-categories"),
      "categories section is shown"
    );

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

  test("category section links are sorted by category name alphabetically", async function (assert) {
    const { category1, category2, category3 } = setupUserSidebarCategories();

    category3.set("name", "aBC");
    category2.set("name", "abc");
    category1.set("name", "efg");

    await visit("/");

    const categorySectionLinks = queryAll(
      ".sidebar-section-categories .sidebar-section-link:not(.sidebar-section-link-all-categories)"
    );

    const categoryNames = [...categorySectionLinks].map((categorySectionLink) =>
      categorySectionLink.textContent.trim()
    );

    assert.deepEqual(
      categoryNames,
      ["abc", "aBC", "efg", "Sub Category"],
      "category section links are displayed in the right order"
    );
  });

  test("category section links", async function (assert) {
    const { category1, category2, category3, category4 } =
      setupUserSidebarCategories();

    await visit("/");

    assert.strictEqual(
      count(
        ".sidebar-section-categories .sidebar-section-link:not(.sidebar-section-link-all-categories)"
      ),
      4,
      "there should only be 4 section link under the section"
    );

    assert.ok(
      exists(
        `.sidebar-section-link-${category1.slug} .sidebar-section-link-prefix .prefix-span[style="background: linear-gradient(90deg, #${category1.color} 50%, #${category1.color} 50%)"]`
      ),
      "category1 section link is rendered with solid prefix icon color"
    );

    assert.strictEqual(
      query(`.sidebar-section-link-${category1.slug}`).textContent.trim(),
      category1.name,
      "displays category1's name for the link text"
    );

    await click(`.sidebar-section-link-${category1.slug}`);

    assert.strictEqual(
      currentURL(),
      `/c/${category1.slug}/${category1.id}`,
      "it should transition to the category1 page"
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
      `/c/${category2.slug}/${category2.id}`,
      "it should transition to the category2's page"
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

    assert.ok(
      exists(
        `.sidebar-section-link-${category3.slug} .sidebar-section-link-prefix .prefix-badge.d-icon-lock`
      ),
      "category3 section link is rendered with lock prefix badge icon as it is read restricted"
    );

    assert.ok(
      exists(
        `.sidebar-section-link-${category4.slug} .sidebar-section-link-prefix .prefix-span[style="background: linear-gradient(90deg, #${category4.parentCategory.color} 50%, #${category4.color} 50%)"]`
      ),
      "sub category section link is rendered with double prefix color"
    );
  });

  test("clicking section links - sidebar_list_destination set to unread/new and no unread or new topics", async function (assert) {
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
    });
    const { category1 } = setupUserSidebarCategories();

    await visit("/");

    await click(`.sidebar-section-link-${category1.slug}`);

    assert.strictEqual(
      currentURL(),
      `/c/${category1.slug}/${category1.id}`,
      "it should transition to the category1 default view page"
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
  });

  test("clicking section links - sidebar_list_destination set to unread/new with new topics", async function (assert) {
    const { category1 } = setupUserSidebarCategories();
    const topicTrackingState = this.container.lookup(
      "service:topic-tracking-state"
    );
    topicTrackingState.states.set("t112", {
      last_read_post_number: null,
      id: 112,
      notification_level: NotificationLevels.TRACKING,
      category_id: category1.id,
      created_in_new_period: true,
    });
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
    });

    await visit("/");

    await click(`.sidebar-section-link-${category1.slug}`);

    assert.strictEqual(
      currentURL(),
      `/c/${category1.slug}/${category1.id}/l/new`,
      "it should transition to the category1 new page"
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
  });

  test("clicking section links - sidebar_list_destination set to unread/new with new and unread topics", async function (assert) {
    const { category1 } = setupUserSidebarCategories();
    const topicTrackingState = this.container.lookup(
      "service:topic-tracking-state"
    );
    topicTrackingState.states.set("t112", {
      last_read_post_number: null,
      id: 112,
      notification_level: NotificationLevels.TRACKING,
      category_id: category1.id,
      created_in_new_period: true,
    });
    topicTrackingState.states.set("t113", {
      last_read_post_number: 1,
      highest_post_number: 2,
      id: 113,
      notification_level: NotificationLevels.TRACKING,
      category_id: category1.id,
      created_in_new_period: true,
    });
    updateCurrentUser({
      sidebar_list_destination: "unread_new",
    });

    await visit("/");

    await click(`.sidebar-section-link-${category1.slug}`);

    assert.strictEqual(
      currentURL(),
      `/c/${category1.slug}/${category1.id}/l/unread`,
      "it should transition to the category1 unread page"
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
  });

  test("category section link for category with 3-digit hex code for color", async function (assert) {
    const { category1 } = setupUserSidebarCategories();
    category1.set("color", "888");

    await visit("/");

    assert.ok(
      exists(
        `.sidebar-section-link-${category1.slug} .sidebar-section-link-prefix .prefix-span[style="background: linear-gradient(90deg, #888 50%, #888 50%)"]`
      ),
      "category1 section link is rendered with the right solid prefix icon color"
    );
  });

  test("category section link have the right title", async function (assert) {
    const categories = Site.current().categories;

    // Category with link HTML tag in description
    const category = categories.find((c) => c.id === 28);

    updateCurrentUser({
      sidebar_category_ids: [category.id],
    });

    await visit("/");

    assert.strictEqual(
      query(`.sidebar-section-link-${category.slug}`).title,
      category.description_text,
      "category description without HTML entity is used as the link's title"
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

  test("visiting category discovery no subcategoriees route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/none`);

    assert.strictEqual(
      count(".sidebar-section-categories .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link-${category1.slug}.active`),
      "the category1 section link is marked as active for the none route"
    );
  });

  test("visiting category discovery includes all subcategories route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/all`);

    assert.strictEqual(
      count(".sidebar-section-categories .sidebar-section-link.active"),
      1,
      "only one link is marked as active"
    );

    assert.ok(
      exists(`.sidebar-section-link-${category1.slug}.active`),
      "the category1 section link is marked as active for the all route"
    );
  });

  test("new and unread count for categories link", async function (assert) {
    const { category1, category2 } = setupUserSidebarCategories();

    this.container.lookup("service:topic-tracking-state").loadStates([
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
        `.sidebar-section-link-${category1.slug} .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.new_count", { count: 1 }),
      `displays 1 new count for ${category1.slug} section link`
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
        `.sidebar-section-link-${category1.slug} .sidebar-section-link-content-badge`
      ),
      `does not display any badge ${category1.slug} section link`
    );

    await publishToMessageBus("/unread", {
      topic_id: 3,
      message_type: "read",
      payload: {
        last_read_post_number: 15,
        highest_post_number: 15,
      },
    });

    assert.strictEqual(
      query(
        `.sidebar-section-link-${category2.slug} .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.unread_count", { count: 1 }),
      `displays 1 unread count for ${category2.slug} section link`
    );
  });

  test("clean up topic tracking state state changed callbacks when Sidebar is collapsed", async function (assert) {
    setupUserSidebarCategories();

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

  test("section link to admin site settings page when default sidebar categories have not been configured", async function (assert) {
    setupUserSidebarCategories();
    updateCurrentUser({ admin: true });

    await visit("/");

    assert.ok(
      exists(".sidebar-section-link-configure-default-sidebar-categories"),
      "section link to configure default sidebar categories is shown"
    );

    await click(".sidebar-section-link-configure-default-sidebar-categories");

    assert.strictEqual(
      currentURL(),
      "/admin/site_settings/category/all_results?filter=default_sidebar_categories",
      "it links to the admin site settings page correctly"
    );
  });
});

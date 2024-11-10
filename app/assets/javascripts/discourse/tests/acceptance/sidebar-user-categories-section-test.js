import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { TOP_SITE_CATEGORIES_TO_SHOW } from "discourse/components/sidebar/common/categories-section";
import { NotificationLevels } from "discourse/lib/notification-levels";
import Site from "discourse/models/site";
import categoryFixture from "discourse/tests/fixtures/category-fixtures";
import discoveryFixture from "discourse/tests/fixtures/discovery-fixtures";
import {
  acceptance,
  count,
  publishToMessageBus,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "discourse-i18n";

acceptance(
  "Sidebar - Logged on user - Categories Section - allow_uncategorized_topics disabled",
  function (needs) {
    needs.settings({
      allow_uncategorized_topics: false,
      navigation_menu: "sidebar",
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
          ".sidebar-section[data-section-name='categories'] .sidebar-section-link:not(.sidebar-section-link[data-link-name='all-categories'])"
        ),
        1,
        "there should only be one section link under the section"
      );

      assert
        .dom(
          `.sidebar-section-link-wrapper[data-category-id="${category1.id}"]`
        )
        .exists(`only the ${category1.slug} section link is shown`);
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
    navigation_menu: "sidebar",
    suppress_uncategorized_badge: false,
    allow_uncategorized_topics: true,
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

    server.get("/categories/hierarchical_search", () => {
      return helper.response({ categories: [] });
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

    await click(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-header"
    );

    assert
      .dom(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-content"
      )
      .doesNotExist("hides the content of the section");
  });

  test("clicking on section header button", async function (assert) {
    setupUserSidebarCategories();

    await visit("/");

    await click(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-header-button"
    );

    assert
      .dom(".sidebar-categories-form")
      .exists("shows the categories form modal");
  });

  test("categories section is shown with site's top categories when user has not added any categories and there are no default categories set for the user", async function (assert) {
    updateCurrentUser({ sidebar_category_ids: [] });

    await visit("/");

    assert
      .dom(".sidebar-section[data-section-name='categories']")
      .exists("categories section is shown");

    const categorySectionLinks = queryAll(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-link-wrapper[data-category-id]"
    );

    assert.strictEqual(
      categorySectionLinks.length,
      TOP_SITE_CATEGORIES_TO_SHOW,
      "the right number of category section links are shown"
    );

    const topCategories = Site.current().categoriesByCount.splice(
      0,
      TOP_SITE_CATEGORIES_TO_SHOW
    );

    topCategories.forEach((category) => {
      assert
        .dom(`.sidebar-section-link-wrapper[data-category-id="${category.id}"]`)
        .exists(`${category.displayName} section link is shown`);
    });
  });

  test("uncategorized category is shown when added to sidebar", async function (assert) {
    const categories = Site.current().categories;

    const uncategorizedCategory = categories.find((category) => {
      return category.isUncategorizedCategory;
    });

    updateCurrentUser({ sidebar_category_ids: [uncategorizedCategory.id] });

    await visit("/");

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${uncategorizedCategory.id}"]`
      )
      .exists(
        `displays the section link for ${uncategorizedCategory.slug} category`
      );
  });

  test("category section links are ordered by category name with child category sorted after parent when site setting to fix category's position is disabled", async function (assert) {
    this.siteSettings.fixed_category_positions = false;

    const site = Site.current();
    const siteCategories = site.categories;

    siteCategories[0].setProperties({
      parent_category_id: -1001,
      id: -1000,
      name: "Parent B Child A",
    });

    siteCategories[1].setProperties({
      parent_category_id: null,
      id: -1001,
      name: "Parent B",
    });

    siteCategories[2].setProperties({
      parent_category_id: null,
      id: -1002,
      name: "Parent A",
    });

    siteCategories[3].setProperties({
      parent_category_id: -1001,
      id: -1003,
      name: "Parent B Child B",
    });

    siteCategories[4].setProperties({
      parent_category_id: -1002,
      id: -1004,
      name: "Parent A Child A",
    });

    siteCategories[5].setProperties({
      parent_category_id: -1000,
      id: -1005,
      name: "Parent B Child A Child A",
    });

    // Changes to ID are not normally expected, let's force a change
    site.notifyPropertyChange("categories");

    updateCurrentUser({
      sidebar_category_ids: [-1005, -1004, -1003, -1002, -1000],
    });

    await visit("/");

    const categorySectionLinks = queryAll(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-link:not(.sidebar-section-link[data-link-name='all-categories'])"
    );

    const categoryNames = [...categorySectionLinks].map((categorySectionLink) =>
      categorySectionLink.textContent.trim()
    );

    assert.deepEqual(
      categoryNames,
      [
        "Parent A",
        "Parent A Child A",
        "Parent B Child A",
        "Parent B Child A Child A",
        "Parent B Child B",
      ],
      "category section links are displayed in the right order"
    );
  });

  test("category section links are ordered by default order of site categories with child category sorted after parent category when site setting to fix category's position is enabled", async function (assert) {
    this.siteSettings.fixed_category_positions = true;

    const site = Site.current();
    const siteCategories = site.categories;

    siteCategories[0].setProperties({
      parent_category_id: -1001,
      id: -1000,
      name: "Parent A Child A",
    });

    siteCategories[1].setProperties({
      parent_category_id: null,
      id: -1001,
      name: "Parent A",
    });

    siteCategories[2].setProperties({
      parent_category_id: null,
      id: -1002,
      name: "Parent B",
    });

    siteCategories[3].setProperties({
      parent_category_id: -1001,
      id: -1003,
      name: "Parent A Child B",
    });

    siteCategories[4].setProperties({
      parent_category_id: -1002,
      id: -1004,
      name: "Parent B Child A",
    });

    siteCategories[5].setProperties({
      parent_category_id: -1000,
      id: -1005,
      name: "Parent A Child A Child A",
    });

    // Changes to ID are not normally expected, let's force a change
    site.notifyPropertyChange("categories");

    updateCurrentUser({
      sidebar_category_ids: [-1005, -1004, -1003, -1002, -1000],
    });

    await visit("/");

    const categorySectionLinks = queryAll(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-link:not(.sidebar-section-link[data-link-name='all-categories'])"
    );

    const categoryNames = [...categorySectionLinks].map((categorySectionLink) =>
      categorySectionLink.textContent.trim()
    );

    assert.deepEqual(
      categoryNames,
      [
        "Parent A Child A",
        "Parent A Child A Child A",
        "Parent A Child B",
        "Parent B",
        "Parent B Child A",
      ],
      "category section links are displayed in the right order"
    );
  });

  test("category section links are ordered by position when site setting to fix category's position is enabled", async function (assert) {
    this.siteSettings.fixed_category_positions = true;

    const site = Site.current();
    const siteCategories = site.categories;

    siteCategories[0].setProperties({
      parent_category_id: -1001,
      id: -1000,
      name: "Parent A Child A",
    });

    siteCategories[1].setProperties({
      parent_category_id: null,
      id: -1001,
      name: "Parent A",
    });

    siteCategories[2].setProperties({
      parent_category_id: null,
      id: -1002,
      name: "Parent B",
    });

    siteCategories[3].setProperties({
      parent_category_id: -1001,
      id: -1003,
      name: "Parent A Child B",
    });

    siteCategories[4].setProperties({
      parent_category_id: -1002,
      id: -1004,
      name: "Parent B Child A",
    });

    siteCategories[5].setProperties({
      parent_category_id: -1000,
      id: -1005,
      name: "Parent A Child A Child A",
    });

    // Changes to ID are not normally expected, let's force a change
    site.notifyPropertyChange("categories");

    updateCurrentUser({
      sidebar_category_ids: [-1005, -1004, -1003, -1002, -1000],
    });

    await visit("/");

    const categorySectionLinks = queryAll(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-link:not(.sidebar-section-link[data-link-name='all-categories'])"
    );

    const categoryNames = [...categorySectionLinks].map((categorySectionLink) =>
      categorySectionLink.textContent.trim()
    );

    assert.deepEqual(
      categoryNames,
      [
        "Parent A Child A",
        "Parent A Child A Child A",
        "Parent A Child B",
        "Parent B",
        "Parent B Child A",
      ],
      "category section links are displayed in the right order"
    );
  });

  test("category section links", async function (assert) {
    const { category1, category2, category3, category4 } =
      setupUserSidebarCategories();

    await visit("/");

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link:not(.sidebar-section-link[data-link-name='all-categories'])"
      ),
      4,
      "there should only be 4 section link under the section"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-prefix .prefix-span[style="background: linear-gradient(90deg, #${category1.color} 50%, #${category1.color} 50%)"]`
      )
      .exists(
        "category1 section link is rendered with solid prefix icon color"
      );

    assert.strictEqual(
      query(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"]`
      ).textContent.trim(),
      category1.name,
      "displays category1's name for the link text"
    );

    await click(
      `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
    );

    assert.strictEqual(
      currentURL(),
      `/c/${category1.slug}/${category1.id}`,
      "it should transition to the category1 page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists("the category1 section link is marked as active");

    await click(
      `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] a`
    );

    assert.strictEqual(
      currentURL(),
      `/c/${category2.slug}/${category2.id}`,
      "it should transition to the category2's page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] a.active`
      )
      .exists("the category2 section link is marked as active");

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category3.id}"] .sidebar-section-link-prefix .prefix-badge.d-icon-lock`
      )
      .exists(
        "category3 section link is rendered with lock prefix badge icon as it is read restricted"
      );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category4.id}"] .sidebar-section-link-prefix .prefix-span[style="background: linear-gradient(90deg, #${category4.parentCategory.color} 50%, #${category4.color} 50%)"]`
      )
      .exists("sub category section link is rendered with double prefix color");
  });

  test("clicking section links - sidebar_link_to_filtered_list set to true and no unread or new topics", async function (assert) {
    updateCurrentUser({
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });
    const { category1 } = setupUserSidebarCategories();

    await visit("/");

    await click(
      `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
    );

    assert.strictEqual(
      currentURL(),
      `/c/${category1.slug}/${category1.id}`,
      "it should transition to the category1 default view page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists("the category1 section link is marked as active");
  });

  test("clicking section links - sidebar_link_to_filtered_list set to true with new topics", async function (assert) {
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
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });

    await visit("/");

    await click(
      `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
    );

    assert.strictEqual(
      currentURL(),
      `/c/${category1.slug}/${category1.id}/l/new`,
      "it should transition to the category1 new page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists("the category1 section link is marked as active");
  });

  test("clicking section links - sidebar_link_to_filtered_list set to true with new and unread topics", async function (assert) {
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
      user_option: {
        sidebar_link_to_filtered_list: true,
      },
    });

    await visit("/");

    await click(
      `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
    );

    assert.strictEqual(
      currentURL(),
      `/c/${category1.slug}/${category1.id}/l/unread`,
      "it should transition to the category1 unread page"
    );

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists("the category1 section link is marked as active");
  });

  test("category section link for category with 3-digit hex code for color", async function (assert) {
    const { category1 } = setupUserSidebarCategories();
    category1.set("color", "888");

    await visit("/");

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-prefix .prefix-span[style="background: linear-gradient(90deg, #888 50%, #888 50%)"]`
      )
      .exists(
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
      query(
        `.sidebar-section-link-wrapper[data-category-id="${category.id}"] a`
      ).title,
      category.descriptionText,
      "category description without HTML entity is used as the link's title"
    );
  });

  test("visiting category discovery new route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/l/new`);

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists(
        "the category1 section link is marked as active for the new route"
      );
  });

  test("visiting category discovery unread route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/l/unread`);

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists(
        "the category1 section link is marked as active for the unread route"
      );
  });

  test("visiting category discovery top route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/l/top`);

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists(
        "the category1 section link is marked as active for the top route"
      );
  });

  test("visiting category discovery no subcategories route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/none`);

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists(
        "the category1 section link is marked as active for the none route"
      );
  });

  test("visiting category discovery includes all subcategories route", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

    await visit(`/c/${category1.slug}/${category1.id}/all`);

    assert.strictEqual(
      count(
        ".sidebar-section[data-section-name='categories'] .sidebar-section-link.active"
      ),
      1,
      "only one link is marked as active"
    );

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a.active`
      )
      .exists(
        "the category1 section link is marked as active for the all route"
      );
  });

  test("show suffix indicator for unread and new content on categories link", async function (assert) {
    const { category1 } = setupUserSidebarCategories();

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
    ]);

    await visit("/");

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-suffix`
      )
      .exists("shows suffix indicator for unread content on categories link");

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
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-suffix`
      )
      .exists("shows suffix indicator for new topics on categories link");

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
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-suffix`
      )
      .doesNotExist(
        "hides suffix indicator when there's no new/unread content on category link"
      );
  });

  test("new and unread count for categories link", async function (assert) {
    const { category1, category2 } = setupUserSidebarCategories();

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
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
      ).textContent.trim(),
      I18n.t("sidebar.unread_count", { count: 1 }),
      `displays 1 unread count for ${category1.slug} section link`
    );

    assert.strictEqual(
      query(
        `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] .sidebar-section-link-content-badge`
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
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
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

    assert
      .dom(
        `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
      )
      .doesNotExist(
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
        `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] .sidebar-section-link-content-badge`
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
    updateCurrentUser({ admin: true });

    await visit("/");

    assert
      .dom(
        ".sidebar-section-link[data-link-name='configure-default-navigation-menu-categories']"
      )
      .exists(
        "section link to configure default navigation menu categories is shown"
      );

    await click(
      ".sidebar-section-link[data-link-name='configure-default-navigation-menu-categories']"
    );

    assert.strictEqual(
      currentURL(),
      "/admin/site_settings/category/all_results?filter=default_navigation_menu_categories",
      "it links to the admin site settings page correctly"
    );
  });
});

acceptance(
  "Sidebar - Logged on user - Categories Section - New new view experiment enabled",
  function (needs) {
    needs.settings({
      navigation_menu: "sidebar",
    });

    needs.user({ new_new_view_enabled: true });

    test("count shown next to category link when sidebar_show_count_of_new_items is true", async function (assert) {
      const categories = Site.current().categories;
      const category1 = categories[0];
      const category2 = categories[1];
      const category3 = categories[2];

      updateCurrentUser({
        sidebar_category_ids: [category1.id, category2.id, category3.id],
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
          last_read_post_number: 15,
          created_at: "2021-06-14T12:41:02.477Z",
          category_id: category1.id,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
        {
          topic_id: 4,
          highest_post_number: 10,
          last_read_post_number: null,
          created_at: "2022-05-11T03:09:31.959Z",
          category_id: category2.id,
          notification_level: null,
          created_in_new_period: true,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
        {
          topic_id: 5,
          highest_post_number: 19,
          last_read_post_number: 18,
          created_at: "2021-06-14T12:41:02.477Z",
          category_id: category3.id,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
      ]);

      await visit("/");

      assert.strictEqual(
        query(
          `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-content-badge`
        ).textContent.trim(),
        "2",
        "count for category1 is 2 because it has 1 unread topic and 1 new topic"
      );

      assert.strictEqual(
        query(
          `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] .sidebar-section-link-content-badge`
        ).textContent.trim(),
        "1",
        "count for category2 is 1 because it has 1 new topic"
      );

      assert.strictEqual(
        query(
          `.sidebar-section-link-wrapper[data-category-id="${category3.id}"] .sidebar-section-link-content-badge`
        ).textContent.trim(),
        "1",
        "count for category3 is 1 because it has 1 unread topic"
      );
    });

    test("dot shown next to category link when sidebar_show_count_of_new_items is false", async function (assert) {
      const categories = Site.current().categories;
      const category1 = categories[0];
      const category2 = categories[1];
      const category3 = categories[2];

      updateCurrentUser({
        sidebar_category_ids: [category1.id, category2.id, category3.id],
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
          category_id: category2.id,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
      ]);

      await visit("/");

      assert
        .dom(
          `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] .sidebar-section-link-suffix.icon.unread`
        )
        .exists("category1 has a dot because it has a new topic");
      assert
        .dom(
          `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] .sidebar-section-link-suffix.icon.unread`
        )
        .exists("category2 has a dot because it has an unread topic");
      assert
        .dom(
          `.sidebar-section-link-wrapper[data-category-id="${category3.id}"] .sidebar-section-link-suffix.icon.unread`
        )
        .doesNotExist(
          "category3 doesn't have a dot because it has no new or unread topics"
        );
    });

    test("category link href is the new topics list of the category when sidebar_link_to_filtered_list is true and there are unread/new topics in the category", async function (assert) {
      const categories = Site.current().categories;
      const category1 = categories[0];
      const category2 = categories[1];
      const category3 = categories[2];

      updateCurrentUser({
        sidebar_category_ids: [category1.id, category2.id, category3.id],
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
          category_id: category2.id,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
        {
          topic_id: 3,
          highest_post_number: 4,
          last_read_post_number: 4,
          created_at: "2020-02-09T09:40:02.672Z",
          category_id: category3.id,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
      ]);

      await visit("/");

      assert.true(
        query(
          `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
        ).href.endsWith("/c/meta/3/l/new"),
        "links to the new topics list for the category because there's 1 new topic"
      );

      assert.true(
        query(
          `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] a`
        ).href.endsWith("/c/howto/10/l/new"),
        "links to the new topics list for the category because there's 1 unread topic"
      );

      assert.true(
        query(
          `.sidebar-section-link-wrapper[data-category-id="${category3.id}"] a`
        ).href.endsWith("/c/feature/spec/26"),
        "links to the latest topics list for the category because there are no unread or new topics"
      );
    });

    test("category link href is always the latest topics list when sidebar_link_to_filtered_list is false", async function (assert) {
      const categories = Site.current().categories;
      const category1 = categories[0];
      const category2 = categories[1];
      const category3 = categories[2];

      updateCurrentUser({
        sidebar_category_ids: [category1.id, category2.id, category3.id],
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
          category_id: category2.id,
          notification_level: 2,
          created_in_new_period: false,
          treat_as_new_topic_start_date: "2022-05-09T03:17:34.286Z",
        },
      ]);

      await visit("/");

      assert
        .dom(
          `.sidebar-section-link-wrapper[data-category-id="${category1.id}"] a`
        )
        .hasAttribute(
          "href",
          "/c/meta/3",
          "category1 links to the latest topics list for the category"
        );

      assert
        .dom(
          `.sidebar-section-link-wrapper[data-category-id="${category2.id}"] a`
        )
        .hasAttribute(
          "href",
          "/c/howto/10",
          "category2 links to the latest topics list for the category"
        );

      assert
        .dom(
          `.sidebar-section-link-wrapper[data-category-id="${category3.id}"] a`
        )
        .hasAttribute(
          "href",
          "/c/feature/spec/26",
          "category3 links to the latest topics list for the category"
        );
    });
  }
);

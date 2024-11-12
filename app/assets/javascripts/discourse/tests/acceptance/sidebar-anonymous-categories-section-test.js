import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import Site from "discourse/models/site";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anonymous - Categories Section", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
  });

  test("category section links ordered by category's topic count when default_navigation_menu_categories has not been configured and site setting to fix categories positions is disabled", async function (assert) {
    this.siteSettings.fixed_category_positions = false;

    await visit("/");

    const categorySectionLinks = queryAll(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-link-wrapper"
    );

    const sidebarCategories = Site.current()
      .categories.filter((category) => !category.parent_category_id)
      .sort((a, b) => b.topic_count - a.topic_count);

    assert.strictEqual(categorySectionLinks.length, 6);

    assert.strictEqual(
      categorySectionLinks[0].textContent.trim(),
      sidebarCategories[0].name
    );

    assert.strictEqual(
      categorySectionLinks[1].textContent.trim(),
      sidebarCategories[1].name
    );

    assert.strictEqual(
      categorySectionLinks[2].textContent.trim(),
      sidebarCategories[2].name
    );

    assert.strictEqual(
      categorySectionLinks[3].textContent.trim(),
      sidebarCategories[3].name
    );

    assert.strictEqual(
      categorySectionLinks[4].textContent.trim(),
      sidebarCategories[4].name
    );

    assert
      .dom("a.sidebar-section-link[data-link-name='all-categories']")
      .exists("all categories link is visible");
  });

  test("category section links ordered by default category's position when default_navigation_menu_categories has not been configured and site setting to fix categories positions is enabled", async function (assert) {
    this.siteSettings.fixed_category_positions = true;

    await visit("/");

    const categories = queryAll(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-link-wrapper"
    );

    const siteCategories = Site.current().categories;

    assert.strictEqual(categories.length, 6);

    assert.strictEqual(
      categories[0].textContent.trim(),
      siteCategories[0].name
    );

    assert.strictEqual(
      categories[1].textContent.trim(),
      siteCategories[1].name
    );

    assert.strictEqual(
      categories[2].textContent.trim(),
      siteCategories[3].name
    );

    assert.strictEqual(
      categories[3].textContent.trim(),
      siteCategories[4].name
    );

    assert.strictEqual(
      categories[4].textContent.trim(),
      siteCategories[5].name
    );

    assert
      .dom("a.sidebar-section-link[data-link-name='all-categories']")
      .exists("all categories link is visible");
  });

  test("category section links in sidebar when default_navigation_menu_categories site setting has been configured and site setting to fix category position is enabled", async function (assert) {
    this.siteSettings.fixed_category_positions = true;
    this.siteSettings.default_navigation_menu_categories = "1|3|13";

    await visit("/");

    const categories = queryAll(
      ".sidebar-section[data-section-name='categories'] .sidebar-section-link-wrapper"
    );

    assert.strictEqual(categories.length, 4);
    assert.strictEqual(categories[0].textContent.trim(), "meta");
    assert.strictEqual(categories[1].textContent.trim(), "blog");
    assert.strictEqual(categories[2].textContent.trim(), "bug");

    assert
      .dom("a.sidebar-section-link[data-link-name='all-categories']")
      .exists("all categories link is visible");
  });

  test("default uncategorized category section links is not shown when allow_uncategorized_topics is disabled", async function (assert) {
    this.siteSettings.allow_uncategorized_topics = false;
    this.siteSettings.fixed_category_positions = true;
    const site = Site.current();

    const firstCategory = site.categories.find((category) => {
      return !category.parent_category_id;
    });

    site.set("uncategorized_category_id", firstCategory.id);

    await visit("/");

    assert
      .dom(
        `.sidebar-section[data-section-name='categories'] .sidebar-section-link[data-link-name='${firstCategory.slug}']`
      )
      .doesNotExist(
        "category section link is not shown in sidebar after being marked as uncategorized"
      );
  });
});

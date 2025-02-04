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
    assert.dom(categorySectionLinks[0]).hasText(sidebarCategories[0].name);
    assert.dom(categorySectionLinks[1]).hasText(sidebarCategories[1].name);
    assert.dom(categorySectionLinks[2]).hasText(sidebarCategories[2].name);
    assert.dom(categorySectionLinks[3]).hasText(sidebarCategories[3].name);
    assert.dom(categorySectionLinks[4]).hasText(sidebarCategories[4].name);

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
    assert.dom(categories[0]).hasText(siteCategories[0].name);
    assert.dom(categories[1]).hasText(siteCategories[1].name);
    assert.dom(categories[2]).hasText(siteCategories[3].name);
    assert.dom(categories[3]).hasText(siteCategories[4].name);
    assert.dom(categories[4]).hasText(siteCategories[5].name);

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
    assert.dom(categories[0]).hasText("meta");
    assert.dom(categories[1]).hasText("blog");
    assert.dom(categories[2]).hasText("bug");

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

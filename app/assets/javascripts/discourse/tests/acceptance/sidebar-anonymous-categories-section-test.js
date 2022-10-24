import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import Site from "discourse/models/site";

acceptance("Sidebar - Anonymous Categories Section", function (needs) {
  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
  });

  test("category section links", async function (assert) {
    await visit("/");

    const categories = queryAll(
      ".sidebar-section-categories .sidebar-section-link-wrapper"
    );
    assert.strictEqual(categories.length, 6);
    assert.strictEqual(categories[0].textContent.trim(), "bug");
    assert.strictEqual(categories[1].textContent.trim(), "dev");
    assert.strictEqual(categories[2].textContent.trim(), "feature");
    assert.strictEqual(categories[3].textContent.trim(), "support");
    assert.strictEqual(categories[4].textContent.trim(), "ux");

    assert.ok(
      exists("a.sidebar-section-link-all-categories"),
      "all categories link is visible"
    );
  });

  test("category section links in sidebar when default_sidebar_categories site setting has been configured", async function (assert) {
    this.siteSettings.default_sidebar_categories = "3|13|1";
    await visit("/");

    const categories = queryAll(
      ".sidebar-section-categories .sidebar-section-link-wrapper"
    );

    assert.strictEqual(categories.length, 4);
    assert.strictEqual(categories[0].textContent.trim(), "blog");
    assert.strictEqual(categories[1].textContent.trim(), "bug");
    assert.strictEqual(categories[2].textContent.trim(), "meta");

    assert.ok(
      exists("a.sidebar-section-link-all-categories"),
      "all categories link is visible"
    );
  });

  test("default uncategorized category section links is not shown when allow_uncategorized_topics is disabled", async function (assert) {
    this.siteSettings.allow_uncategorized_topics = false;
    this.siteSettings.fixed_category_positions = true;
    const site = Site.current();

    const firstCategory = Site.current().categories.find((category) => {
      return !category.parent_category_id;
    });

    site.set("uncategorized_category_id", firstCategory.id);

    await visit("/");

    assert.notOk(
      exists(
        `.sidebar-section-categories .sidebar-section-link-${firstCategory.slug}`
      ),
      "category section link is not shown in sidebar after being marked as uncategorized"
    );
  });
});

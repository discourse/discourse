import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anonymous Categories Section", function (needs) {
  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
    suppress_uncategorized_badge: false,
  });

  test("category section links", async function (assert) {
    await visit("/");

    const categories = queryAll(
      ".sidebar-section-categories .sidebar-section-link-wrapper"
    );
    assert.strictEqual(categories.length, 6);
    assert.strictEqual(categories[0].textContent.trim(), "meta");
    assert.strictEqual(categories[1].textContent.trim(), "howto");
    assert.strictEqual(categories[2].textContent.trim(), "dev");
    assert.strictEqual(categories[3].textContent.trim(), "support");
    assert.strictEqual(categories[4].textContent.trim(), "Shared Drafts");

    assert.ok(
      exists("a.sidebar-section-link-more-categories"),
      "more link is visible"
    );
  });

  test("default sidebar categories", async function (assert) {
    this.siteSettings.default_sidebar_categories = "3|13|1";
    await visit("/");

    const categories = queryAll(
      ".sidebar-section-categories .sidebar-section-link-wrapper"
    );

    assert.strictEqual(categories.length, 4);
    assert.strictEqual(categories[0].textContent.trim(), "meta");
    assert.strictEqual(categories[1].textContent.trim(), "blog");
    assert.strictEqual(categories[2].textContent.trim(), "bug");

    assert.ok(
      exists("a.sidebar-section-link-more-categories"),
      "more link is visible"
    );
  });
});

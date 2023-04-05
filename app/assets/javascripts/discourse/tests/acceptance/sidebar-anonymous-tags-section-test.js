import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import Site from "discourse/models/site";

acceptance("Sidebar - Anonymous Tags Section", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
    suppress_uncategorized_badge: false,
    tagging_enabled: true,
  });

  needs.site({
    top_tags: ["design", "development", "fun"],
  });

  test("tag section links when site has top tags", async function (assert) {
    await visit("/");

    const categories = queryAll(
      ".sidebar-section[data-section-name='tags'] .sidebar-section-link-wrapper"
    );

    assert.strictEqual(categories.length, 4);
    assert.strictEqual(categories[0].textContent.trim(), "design");
    assert.strictEqual(categories[1].textContent.trim(), "development");
    assert.strictEqual(categories[2].textContent.trim(), "fun");

    assert.ok(
      exists("a.sidebar-section-link-all-tags"),
      "all tags link is visible"
    );
  });

  test("tag section links when site has default sidebar tags configured", async function (assert) {
    const site = Site.current();
    site.set("anonymous_default_sidebar_tags", ["random", "meta"]);

    await visit("/");

    const categories = queryAll(
      ".sidebar-section[data-section-name='tags'] .sidebar-section-link-wrapper"
    );
    assert.strictEqual(categories.length, 3);
    assert.strictEqual(categories[0].textContent.trim(), "random");
    assert.strictEqual(categories[1].textContent.trim(), "meta");

    assert.ok(
      exists("a.sidebar-section-link-all-tags"),
      "all tags link is visible"
    );
  });

  test("tag section is hidden when tagging is disabled", async function (assert) {
    this.siteSettings.tagging_enabled = false;

    await visit("/");

    assert.ok(
      !exists(".sidebar-section[data-section-name='tags']"),
      "section is not visible"
    );
  });

  test("tag section is hidden when anonymous has no visible top tags and site has not default sidebar tags configured", async function (assert) {
    const site = Site.current();

    site.setProperties({
      top_tags: [],
      anonymous_default_sidebar_tags: [],
    });

    await visit("/");

    assert.ok(
      !exists(".sidebar-section[data-section-name='tags']"),
      "section is not visible"
    );
  });
});

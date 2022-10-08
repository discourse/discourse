import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anonymous Tags Section", function (needs) {
  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
    suppress_uncategorized_badge: false,
    tagging_enabled: true,
  });

  needs.site({
    top_tags: ["design", "development", "fun"],
  });

  test("tag section links", async function (assert) {
    await visit("/");

    const categories = queryAll(
      ".sidebar-section-tags .sidebar-section-link-wrapper"
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
});

acceptance("Sidebar - Anonymous Tags Section - default tags", function (needs) {
  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
    suppress_uncategorized_badge: false,
    tagging_enabled: true,
  });

  needs.site({
    top_tags: ["design", "development", "fun"],
    anonymous_default_sidebar_tags: ["random", "meta"],
  });

  test("tag section links", async function (assert) {
    await visit("/");

    const categories = queryAll(
      ".sidebar-section-tags .sidebar-section-link-wrapper"
    );
    assert.strictEqual(categories.length, 3);
    assert.strictEqual(categories[0].textContent.trim(), "random");
    assert.strictEqual(categories[1].textContent.trim(), "meta");

    assert.ok(
      exists("a.sidebar-section-link-all-tags"),
      "all tags link is visible"
    );
  });
});

acceptance(
  "Sidebar - Anonymous Tags Section - Tagging disabled",
  function (needs) {
    needs.settings({
      enable_experimental_sidebar_hamburger: true,
      enable_sidebar: true,
      suppress_uncategorized_badge: false,
      tagging_enabled: false,
    });

    needs.site({
      top_tags: ["design", "development", "fun"],
    });

    test("tag section links", async function (assert) {
      await visit("/");

      assert.ok(!exists(".sidebar-section-tags"), "section is not visible");
    });
  }
);

import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Categories - 'categories_only'", function (needs) {
  needs.settings({
    desktop_category_page_style: "categories_only",
  });
  test("basic functionality", async function (assert) {
    await visit("/categories");
    assert.ok(
      exists("table.category-list tr[data-category-id=1]"),
      "shows the topic list"
    );
  });
});

acceptance("Categories - 'categories_and_latest_topics'", function (needs) {
  needs.settings({
    desktop_category_page_style: "categories_and_latest_topics",
  });
  test("basic functionality", async function (assert) {
    await visit("/categories");
    assert.ok(
      exists("table.category-list tr[data-category-id=1]"),
      "shows a category"
    );
    assert.ok(
      exists("div.latest-topic-list div[data-topic-id=8]"),
      "shows the topic list"
    );
    assert.ok(
      query(".more-topics a").href.endsWith("/latest"),
      "the load more button doesn't add the order param if desktop_category_page_sort_order is not set"
    );
  });
});

acceptance(
  "Categories - 'categories_and_latest_topics' - order by",
  function (needs) {
    needs.settings({
      desktop_category_page_style: "categories_and_latest_topics",
      desktop_category_page_sort_order: "new_world_order",
    });
    test("order topics by", async function (assert) {
      await visit("/categories");

      assert.ok(
        query(".more-topics a").href.endsWith("?order=new_world_order"),
        "the load more button matches the desktop_category_page_sort_order setting"
      );
    });
  }
);

acceptance("Categories - 'categories_with_featured_topics'", function (needs) {
  needs.settings({
    desktop_category_page_style: "categories_with_featured_topics",
  });
  test("basic functionality", async function (assert) {
    await visit("/categories");
    assert.ok(
      exists("table.category-list.with-topics tr[data-category-id=1]"),
      "shows a category"
    );
    assert.ok(
      exists("table.category-list.with-topics div[data-topic-id=11994]"),
      "shows a featured topic"
    );
  });
});

acceptance(
  "Categories - 'subcategories_with_featured_topics'",
  function (needs) {
    needs.settings({
      desktop_category_page_style: "subcategories_with_featured_topics",
    });
    test("basic functionality", async function (assert) {
      await visit("/categories");
      assert.ok(
        exists("table.subcategory-list.with-topics thead h3 .category-name"),
        "shows heading for top-level category"
      );
      assert.ok(
        exists(
          "table.subcategory-list.with-topics tr[data-category-id=26] h3 .category-name"
        ),
        "shows table row for subcategories"
      );
      assert.ok(
        exists("table.category-list.with-topics div[data-topic-id=11994]"),
        "shows a featured topic"
      );
    });
  }
);

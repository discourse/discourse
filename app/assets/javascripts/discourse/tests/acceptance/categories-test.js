import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import PreloadStore from "discourse/lib/preload-store";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Categories - 'categories_only'", function (needs) {
  needs.settings({
    desktop_category_page_style: "categories_only",
  });

  test("basic functionality", async function (assert) {
    await visit("/categories");
    assert
      .dom("table.category-list tr[data-category-id='1']")
      .exists("shows the topic list");
  });
});

acceptance("Categories - 'categories_and_latest_topics'", function (needs) {
  needs.settings({
    desktop_category_page_style: "categories_and_latest_topics",
  });

  test("basic functionality", async function (assert) {
    await visit("/categories");
    assert
      .dom("table.category-list tr[data-category-id='1']")
      .exists("shows a category");
    assert
      .dom("div.latest-topic-list div[data-topic-id='8']")
      .exists("shows the topic list");
    assert
      .dom(".more-topics a")
      .hasAttribute(
        "href",
        "/latest",
        "the load more button doesn't include the order=created param"
      );
  });
});

acceptance(
  "Categories - 'categories_and_latest_topics' - order by created date",
  function (needs) {
    needs.settings({
      desktop_category_page_style: "categories_and_latest_topics_created_date",
    });

    test("order topics by", async function (assert) {
      await visit("/categories");

      assert
        .dom(".more-topics a")
        .hasAttribute(
          "href",
          "/latest?order=created",
          "the load more button includes the order=created param"
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
    assert
      .dom("table.category-list.with-topics tr[data-category-id='1']")
      .exists("shows a category");
    assert
      .dom("table.category-list.with-topics div[data-topic-id='11994']")
      .exists("shows a featured topic");
  });
});

acceptance(
  "Categories - 'subcategories_with_featured_topics' (desktop)",
  function (needs) {
    needs.settings({
      desktop_category_page_style: "subcategories_with_featured_topics",
    });

    test("basic functionality", async function (assert) {
      await visit("/categories");
      assert
        .dom("table.subcategory-list.with-topics thead h3 .category-name")
        .exists("shows heading for top-level category");
      assert
        .dom(
          "table.subcategory-list.with-topics tr[data-category-id='26'] h3 .category-name"
        )
        .exists("shows table row for subcategories");
      assert
        .dom("table.category-list.with-topics div[data-topic-id='11994']")
        .exists("shows a featured topic");
    });
  }
);

acceptance(
  "Categories - 'subcategories_with_featured_topics' (mobile)",
  function (needs) {
    needs.mobileView();
    needs.settings({
      desktop_category_page_style: "subcategories_with_featured_topics",
    });

    test("basic functionality", async function (assert) {
      await visit("/categories");
      assert
        .dom("div.subcategory-list.with-topics h3 .category-name")
        .exists("shows heading for top-level category");
      assert
        .dom(
          "div.subcategory-list.with-topics div[data-category-id='26'] h3 .category-name"
        )
        .exists("shows element for subcategories");
      assert
        .dom("div.category-list.with-topics a[data-topic-id='11994']")
        .exists("shows a featured topic");
    });
  }
);

acceptance("Categories - preloadStore handling", function () {
  const styles = [
    "categories_only",
    "categories_with_featured_topics",
    "categories_and_latest_topics_created_date",
    "categories_and_latest_topics",
    "categories_and_top_topics",
    "categories_boxes",
    "categories_boxes_with_topics",
    "subcategories_with_featured_topics",
  ];

  for (const style of styles) {
    test(`${style} deletes data from PreloadStore to ensure it isn't left for another route`, async function (assert) {
      this.siteSettings.desktop_category_page_style = style;
      PreloadStore.store(
        "topic_list",
        cloneJSON(discoveryFixtures["/latest.json"])
      );
      PreloadStore.store(
        "categories_list",
        cloneJSON(discoveryFixtures["/categories.json"])
      );

      await visit(`/categories`);

      assert.true(
        PreloadStore.get("topic_list") === undefined,
        `topic_list is removed from preloadStore for ${style}`
      );
      assert.true(
        PreloadStore.get("categories_list") === undefined,
        `topic_list is removed from preloadStore for ${style}`
      );
    });
  }
});

import { array } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | Helper | dCategoryBadge", function (hooks) {
  setupRenderingTest(hooks);

  test("displays category", async function (assert) {
    const category = Category.findById(1);

    await render(<template>{{dCategoryBadge category}}</template>);

    assert.dom(".badge-category__name").hasText(category.displayName);
  });

  test("options.link", async function (assert) {
    const category = Category.findById(1);

    await render(<template>{{dCategoryBadge category link=true}}</template>);

    assert
      .dom(
        `a.badge-category__wrapper[href="/c/${category.slug}/${category.id}"]`
      )
      .exists();
  });

  // The renderer has always supported these; the helper simply did not pass them through, so a
  // ui-kit consumer could not build the badge core's own category row builds.
  test("options.topicCount", async function (assert) {
    const category = Category.findById(1);

    await render(
      <template>{{dCategoryBadge category topicCount=128}}</template>
    );

    assert
      .dom(".topic-count")
      .hasText("× 128")
      .hasAttribute(
        "aria-label",
        i18n("category_row.topic_count", { count: 128 }),
        "the count names itself rather than reading as a bare number"
      );
  });

  test("options.subcategoryCount", async function (assert) {
    const category = Category.findById(1);

    await render(
      <template>{{dCategoryBadge category subcategoryCount=3}}</template>
    );

    assert
      .dom(".plus-subcategories")
      .hasText(i18n("category_row.subcategory_count", { count: 3 }));
  });

  test("options.readOnly", async function (assert) {
    const category = Category.findById(1);

    await render(
      <template>{{dCategoryBadge category readOnly=true}}</template>
    );

    assert.dom(".read-only").hasText(i18n("category_row.read_only"));
  });

  test("options.ancestors renders the chain outermost first", async function (assert) {
    const category = Category.findById(1);
    const parent = Category.findById(2);

    await render(
      <template>
        {{dCategoryBadge category ancestors=(array parent) topicCount=7}}
      </template>
    );

    assert
      .dom(".badge-category__name")
      .exists({ count: 2 }, "both the category and its ancestor render");
    assert
      .dom(".badge-category__name")
      .hasText(parent.displayName, "the ancestor comes first");
    assert
      .dom(".topic-count")
      .exists({ count: 1 }, "only the leaf carries the count");
  });
});

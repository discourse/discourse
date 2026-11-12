import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";

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

  test("options.ancestors", async function (assert) {
    const parent = Category.findById(1001);
    const subcategory = Category.findById(1002);
    const ancestors = subcategory.predecessors;

    await render(
      <template>
        {{dCategoryBadge subcategory ancestors=ancestors hideParent=true}}
      </template>
    );

    assert
      .dom(".badge-category__wrapper")
      .exists({ count: 2 }, "renders one badge per category in the chain");
    assert.deepEqual(
      findAll(".badge-category__name").map((el) => el.textContent.trim()),
      [parent.displayName, subcategory.displayName],
      "the parent badge precedes the sub-category badge"
    );
  });
});

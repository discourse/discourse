import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import categoryBadge from "discourse/helpers/category-badge";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | category-badge", function (hooks) {
  setupRenderingTest(hooks);

  test("displays category", async function (assert) {
    const category = Category.findById(1);

    await render(<template>{{categoryBadge category}}</template>);

    assert.dom(".badge-category__name").hasText(category.displayName);
  });

  test("options.link", async function (assert) {
    const category = Category.findById(1);

    await render(<template>{{categoryBadge category link=true}}</template>);

    assert
      .dom(
        `a.badge-category__wrapper[href="/c/${category.slug}/${category.id}"]`
      )
      .exists();
  });
});

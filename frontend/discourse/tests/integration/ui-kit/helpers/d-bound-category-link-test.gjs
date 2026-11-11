import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dBoundCategoryLink from "discourse/ui-kit/helpers/d-bound-category-link";

module("Integration | ui-kit | Helper | dBoundCategoryLink", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the category link with the options", async function (assert) {
    const category = Category.findById(1);

    await render(
      <template>{{dBoundCategoryLink category extraClasses="gizmo"}}</template>
    );

    assert
      .dom(
        `a.badge-category__wrapper.gizmo[href="/c/${category.slug}/${category.id}"]`
      )
      .exists();
  });
});

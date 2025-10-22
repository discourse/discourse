import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DNavigation from "discourse/components/d-navigation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | d-navigation", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const categories = this.site.categoriesList
      .filter((category) => !category.parent_category_id)
      .slice(0, 4);
    this.site.setProperties({ categories });

    this.currentUser.set(
      "indirectly_muted_category_ids",
      categories.slice(0, 3).map((category) => category.id)
    );
  });

  test("filters indirectly muted categories", async function (assert) {
    await render(<template><DNavigation @filterMode="categories" /></template>);
    await click(".category-drop .select-kit-header-wrapper");

    assert
      .dom(".category-row")
      .exists({ count: 1 }, "displays only categories that are not muted");
    assert.dom(".category-row .badge-category span").hasText("dev");
  });
});

import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DNavigation from "discourse/components/d-navigation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | DNavigation", function (hooks) {
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

  test("shows the category as a filter token", async function (assert) {
    const category = this.site.categories[0];

    await render(<template><DNavigation @category={{category}} /></template>);

    assert
      .dom(
        `.discovery-filter-bar .filter-navigation-token[data-token='category:${category.slug}']`
      )
      .exists();
  });
});

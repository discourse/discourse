import { click } from "@ember/test-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | d-navigation", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("filters indirectly muted categories", {
    template: hbs`
      {{d-navigation
        filterType="categories"
      }}
    `,

    beforeEach() {
      const categories = this.site.categoriesList
        .filter((category) => !category.parent_category_id)
        .slice(0, 4);
      this.site.setProperties({ categories });
      this.currentUser.set(
        "indirectly_muted_category_ids",
        categories.slice(0, 3).map((category) => category.id)
      );
    },

    async test(assert) {
      await click(".category-drop .select-kit-header-wrapper");
      assert.strictEqual(
        document.querySelectorAll(".category-row").length,
        1,
        "displays only categories that are not muted"
      );
      assert.strictEqual(
        query(".category-row .badge-category span").textContent.trim(),
        "dev"
      );
    },
  });
});

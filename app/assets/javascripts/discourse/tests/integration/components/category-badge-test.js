import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import Category from "discourse/models/category";

discourseModule("Integration | Component | category-badge", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("displays category", {
    template: hbs`{{category-badge category}}`,

    beforeEach() {
      this.set("category", Category.findById(1));
    },

    async test(assert) {
      assert.equal(
        query(".category-name").innerText.trim(),
        this.category.name
      );
    },
  });

  componentTest("options.link", {
    template: hbs`{{category-badge category link=true}}`,

    beforeEach() {
      this.set("category", Category.findById(1));
    },

    async test(assert) {
      assert.ok(
        exists(
          `a.badge-wrapper[href="/c/${this.category.slug}/${this.category.id}"]`
        )
      );
    },
  });
});

import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { count, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

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
    await render(hbs`<DNavigation @filterMode="categories" />`);
    await click(".category-drop .select-kit-header-wrapper");

    assert.strictEqual(
      count(".category-row"),
      1,
      "displays only categories that are not muted"
    );
    assert.strictEqual(
      query(".category-row .badge-category span").textContent.trim(),
      "dev"
    );
  });
});

import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | category-badge", function (hooks) {
  setupRenderingTest(hooks);

  test("displays category", async function (assert) {
    this.set("category", Category.findById(1));

    await render(hbs`{{category-badge this.category}}`);

    assert.dom(".badge-category__name").hasText(this.category.displayName);
  });

  test("options.link", async function (assert) {
    this.set("category", Category.findById(1));

    await render(hbs`{{category-badge this.category link=true}}`);

    assert
      .dom(
        `a.badge-category__wrapper[href="/c/${this.category.slug}/${this.category.id}"]`
      )
      .exists();
  });
});

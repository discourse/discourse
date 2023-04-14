import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import Category from "discourse/models/category";

module("Integration | Component | category-badge helper", function (hooks) {
  setupRenderingTest(hooks);

  test("displays category", async function (assert) {
    this.set("category", Category.findById(1));

    await render(hbs`{{category-badge category}}`);

    assert.strictEqual(
      query(".category-name").innerText.trim(),
      this.category.name
    );
  });

  test("options.link", async function (assert) {
    this.set("category", Category.findById(1));

    await render(hbs`{{category-badge category link=true}}`);

    assert.ok(
      exists(
        `a.badge-wrapper[href="/c/${this.category.slug}/${this.category.id}"]`
      )
    );
  });
});

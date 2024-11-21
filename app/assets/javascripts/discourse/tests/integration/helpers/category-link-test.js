import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | category-link", function (hooks) {
  setupRenderingTest(hooks);

  test("name", async function (assert) {
    await render(hbs`{{category-link (hash name="foo")}}`);

    assert.dom(".badge-category__name").hasText("foo");
  });

  test("description_text", async function (assert) {
    await render(
      hbs`{{category-link (hash name="foo" description_text="bar")}}`
    );

    assert.dom(".badge-category").hasAttribute("title", "bar");
  });
});

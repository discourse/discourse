import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import categoryLink from "discourse/helpers/category-link";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | category-link", function (hooks) {
  setupRenderingTest(hooks);

  test("name", async function (assert) {
    await render(<template>{{categoryLink (hash name="foo")}}</template>);

    assert.dom(".badge-category__name").hasText("foo");
  });

  test("description_text", async function (assert) {
    await render(
      <template>
        {{categoryLink (hash name="foo" description_text="bar")}}
      </template>
    );

    assert.dom(".badge-category").hasAttribute("title", "bar");
  });
});

import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";

module("Integration | ui-kit | Helper | dCategoryLink", function (hooks) {
  setupRenderingTest(hooks);

  test("name", async function (assert) {
    await render(<template>{{dCategoryLink (hash name="foo")}}</template>);

    assert.dom(".badge-category__name").hasText("foo");
  });

  test("description_text", async function (assert) {
    await render(
      <template>
        {{dCategoryLink (hash name="foo" description_text="bar")}}
      </template>
    );

    assert.dom(".badge-category").hasAttribute("title", "bar");
  });

  test("styleType option", async function (assert) {
    await render(
      <template>
        {{dCategoryLink (hash name="test-cat") styleType="icon" icon="user"}}
      </template>
    );

    assert.dom(".badge-category").hasClass("--style-icon");
    assert.dom(".d-icon-user").exists();
  });

  test("category.style_type auto-detection", async function (assert) {
    await render(
      <template>
        {{dCategoryLink (hash name="icon-cat" style_type="icon" icon="user")}}
      </template>
    );

    assert.dom(".badge-category").hasClass("--style-icon");
    assert.dom(".d-icon-user").exists();
  });

  test("style falls back to square", async function (assert) {
    await render(
      <template>{{dCategoryLink (hash name="square-cat")}}</template>
    );

    assert.dom(".badge-category").hasClass("--style-square");
  });
});

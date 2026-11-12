import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";

module("Integration | ui-kit | Helper | dIconOrImage", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the image when there is one", async function (assert) {
    const badge = { icon: "far fa-heart", image: "/images/gadget.png" };

    await render(
      <template>
        <div class="test">{{dIconOrImage badge}}</div>
      </template>
    );

    assert.dom(".test img").hasAttribute("src", "/images/gadget.png");
    assert.dom(".test img").hasAttribute("alt", "");
    assert.dom(".test svg").doesNotExist();
  });

  test("renders the icon from its class name", async function (assert) {
    const badge = { icon: "far fa-heart" };

    await render(
      <template>
        <div class="test">{{dIconOrImage badge}}</div>
      </template>
    );

    assert.dom(".test svg use").hasAttribute("href", "#far-heart");
  });

  test("renders nothing without an icon or image", async function (assert) {
    const badge = {};

    await render(
      <template>
        <div class="test">{{dIconOrImage badge}}</div>
      </template>
    );

    assert.dom(".test").hasNoText();
    assert.dom(".test *").doesNotExist();
  });
});

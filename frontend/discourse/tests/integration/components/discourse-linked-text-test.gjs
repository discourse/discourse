import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DiscourseLinkedText from "discourse/components/discourse-linked-text";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | DiscourseLinkedText", function (hooks) {
  setupRenderingTest(hooks);

  test("interpolates the text params into the translation", async function (assert) {
    await render(
      <template>
        <DiscourseLinkedText
          @text="pwa.install_banner"
          @textParams={{hash title="Discourse"}}
        />
      </template>
    );

    assert
      .dom("span")
      .hasText(
        "Do you want to install Discourse on this device?",
        "renders the translation with its params applied"
      );
  });

  test("calls the action when the link is clicked", async function (assert) {
    let received = "not called";
    const linkClicked = (param) => (received = param);

    await render(
      <template>
        <DiscourseLinkedText
          @action={{linkClicked}}
          @actionParam="param"
          @text="pwa.install_banner"
          @textParams={{hash title="Discourse"}}
        />
      </template>
    );

    await click("span");
    assert.strictEqual(received, "not called", "ignores clicks off the link");

    await click("a");
    assert.strictEqual(received, "param", "passes the action param through");
  });
});

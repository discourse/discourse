import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Discourse Chat | Component | chat-composer-dropdown", function (hooks) {
  setupRenderingTest(hooks);

  test("buttons", async function (assert) {
    this.set("buttons", [{ id: "foo", icon: "xmark", action: () => {} }]);

    await render(hbs`<ChatComposerDropdown @buttons={{this.buttons}} />`);
    await click(".chat-composer-dropdown__trigger-btn");

    assert.dom(".chat-composer-dropdown__item.foo").exists();
    assert
      .dom(".chat-composer-dropdown__action-btn.foo .d-icon-xmark")
      .exists();
  });
});

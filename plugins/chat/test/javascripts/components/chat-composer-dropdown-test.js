import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";

module("Discourse Chat | Component | chat-composer-dropdown", function (hooks) {
  setupRenderingTest(hooks);

  test("buttons", async function (assert) {
    this.set("buttons", [{ id: "foo", icon: "times", action: () => {} }]);

    await render(hbs`<ChatComposerDropdown @buttons={{this.buttons}} />`);
    await click(".chat-composer-dropdown__trigger-btn");

    assert.true(exists(".chat-composer-dropdown__item.foo"));
    assert.true(
      exists(".chat-composer-dropdown__action-btn.foo .d-icon-times")
    );
  });
});

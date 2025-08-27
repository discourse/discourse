import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatComposerDropdown from "discourse/plugins/chat/discourse/components/chat-composer-dropdown";

module("Discourse Chat | Component | chat-composer-dropdown", function (hooks) {
  setupRenderingTest(hooks);

  test("buttons", async function (assert) {
    const self = this;

    this.set("buttons", [{ id: "foo", icon: "xmark", action: () => {} }]);

    await render(
      <template><ChatComposerDropdown @buttons={{self.buttons}} /></template>
    );
    await click(".chat-composer-dropdown__trigger-btn");

    assert.dom(".chat-composer-dropdown__item.foo").exists();
    assert
      .dom(".chat-composer-dropdown__action-btn.foo .d-icon-xmark")
      .exists();
  });
});

import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module(
  "Discourse Chat | Component | chat-composer-inline-buttons",
  function (hooks) {
    setupRenderingTest(hooks);

    test("buttons", async function (assert) {
      this.set("buttons", [{ id: "foo", icon: "times", action: () => {} }]);

      await render(
        hbs`<ChatComposerInlineButtons @buttons={{this.buttons}} />`
      );

      assert.true(exists(".chat-composer-inline-button.foo"));
      assert.true(exists(".chat-composer-inline-button.foo .d-icon-times"));
    });
  }
);

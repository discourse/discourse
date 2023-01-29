import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module(
  "Discourse Chat | Component | chat-channel-settings-saved-indicator",
  function (hooks) {
    setupRenderingTest(hooks);

    test("when property changes", async function (assert) {
      await render(
        hbs`<ChatChannelSettingsSavedIndicator @property={{this.property}} />`
      );

      assert
        .dom(".chat-channel-settings-saved-indicator.is-active")
        .doesNotExist();

      this.set("property", 1);

      assert.dom(".chat-channel-settings-saved-indicator.is-active").exists();

      await settled();

      assert
        .dom(".chat-channel-settings-saved-indicator.is-active")
        .doesNotExist();
    });
  }
);

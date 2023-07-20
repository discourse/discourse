import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module(
  "Discourse Chat | Component | chat-message-separator-new",
  function (hooks) {
    setupRenderingTest(hooks);

    test("newest message", async function (assert) {
      this.set("message", { newest: true });

      await render(hbs`<ChatMessageSeparatorNew @message={{this.message}} />`);

      assert.strictEqual(
        query(".chat-message-separator-new").innerText.trim(),
        I18n.t("chat.last_visit")
      );
    });
  }
);

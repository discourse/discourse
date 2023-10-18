import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

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

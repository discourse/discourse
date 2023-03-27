import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module(
  "Discourse Chat | Component | chat-message-separator-date",
  function (hooks) {
    setupRenderingTest(hooks);

    test("first message of the day", async function (assert) {
      this.set("date", moment().format("LLL"));
      this.set("message", { firstMessageOfTheDayAt: this.date });

      await render(hbs`<ChatMessageSeparatorDate @message={{this.message}} />`);

      assert.strictEqual(
        query(".chat-message-separator-date").innerText.trim(),
        this.date
      );
    });
  }
);

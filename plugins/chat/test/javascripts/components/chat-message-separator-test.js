import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module("Discourse Chat | Component | chat-message-separator", function (hooks) {
  setupRenderingTest(hooks);

  test("newest message", async function (assert) {
    this.set("message", { newestMessage: true });

    await render(hbs`<ChatMessageSeparator @message={{this.message}} />`);

    assert.strictEqual(
      query(".chat-message-separator.new-message .text").innerText.trim(),
      I18n.t("chat.new_messages")
    );
  });

  test("first message of the day", async function (assert) {
    this.set("date", moment().format("LLL"));
    this.set("message", { firstMessageOfTheDayAt: this.date });

    await render(hbs`<ChatMessageSeparator @message={{this.message}} />`);

    assert.strictEqual(
      query(
        ".chat-message-separator.first-daily-message .text"
      ).innerText.trim(),
      this.date
    );
  });
});

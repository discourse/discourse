import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";
import { module } from "qunit";

module("Discourse Chat | Component | chat-message-separator", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("newest message", {
    template: hbs`{{chat-message-separator message=message}}`,

    async beforeEach() {
      this.set("message", { newestMessage: true });
    },

    async test(assert) {
      assert.equal(
        query(".chat-message-separator.new-message .text").innerText.trim(),
        I18n.t("chat.new_messages")
      );
    },
  });

  componentTest("first message of the day", {
    template: hbs`{{chat-message-separator message=message}}`,

    async beforeEach() {
      this.set("date", moment().format("LLL"));
      this.set("message", { firstMessageOfTheDayAt: this.date });
    },

    async test(assert) {
      assert.equal(
        query(
          ".chat-message-separator.first-daily-message .text"
        ).innerText.trim(),
        this.date
      );
    },
  });
});

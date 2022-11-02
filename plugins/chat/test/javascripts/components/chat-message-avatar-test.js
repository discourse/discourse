import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { module } from "qunit";

module("Discourse Chat | Component | chat-message-avatar", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("chat_webhook_event", {
    template: hbs`{{chat-message-avatar message=message}}`,

    beforeEach() {
      this.set("message", { chat_webhook_event: { emoji: ":heart:" } });
    },

    async test(assert) {
      assert.equal(query(".chat-emoji-avatar .emoji").title, "heart");
    },
  });

  componentTest("user", {
    template: hbs`{{chat-message-avatar message=message}}`,

    beforeEach() {
      this.set("message", { user: { username: "discobot" } });
    },

    async test(assert) {
      assert.ok(exists('.chat-user-avatar [data-user-card="discobot"]'));
    },
  });
});

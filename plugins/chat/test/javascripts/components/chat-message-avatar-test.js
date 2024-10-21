import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Discourse Chat | Component | chat-message-avatar", function (hooks) {
  setupRenderingTest(hooks);

  test("chat_webhook_event", async function (assert) {
    this.message = ChatMessage.create(
      new ChatFabricators(getOwner(this)).channel(),
      {
        chat_webhook_event: { emoji: ":heart:" },
      }
    );

    await render(hbs`<Chat::Message::Avatar @message={{this.message}} />`);

    assert.dom(".chat-emoji-avatar .emoji").hasAttribute("title", "heart");
  });

  test("user", async function (assert) {
    this.message = ChatMessage.create(
      new ChatFabricators(getOwner(this)).channel(),
      {
        user: { username: "discobot" },
      }
    );

    await render(hbs`<Chat::Message::Avatar @message={{this.message}} />`);

    assert.true(exists('.chat-user-avatar [data-user-card="discobot"]'));
  });
});

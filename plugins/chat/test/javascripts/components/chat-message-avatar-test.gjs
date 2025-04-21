import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Avatar from "discourse/plugins/chat/discourse/components/chat/message/avatar";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Discourse Chat | Component | chat-message-avatar", function (hooks) {
  setupRenderingTest(hooks);

  test("chat_webhook_event", async function (assert) {
    const self = this;

    this.message = ChatMessage.create(
      new ChatFabricators(getOwner(this)).channel(),
      {
        chat_webhook_event: { emoji: ":heart:" },
      }
    );

    await render(<template><Avatar @message={{self.message}} /></template>);

    assert.dom(".chat-emoji-avatar .emoji").hasAttribute("title", "heart");
  });

  test("user", async function (assert) {
    const self = this;

    this.message = ChatMessage.create(
      new ChatFabricators(getOwner(this)).channel(),
      {
        user: { username: "discobot" },
      }
    );

    await render(<template><Avatar @message={{self.message}} /></template>);

    assert.dom('.chat-user-avatar [data-user-card="discobot"]').exists();
  });
});

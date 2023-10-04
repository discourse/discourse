import { module, test } from "qunit";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Discourse Chat | Unit |  Models | chat-message", function () {
  test(".persisted", function (assert) {
    const channel = fabricators.channel();
    let message = ChatMessage.create(channel, { id: null });
    assert.strictEqual(message.persisted, false);

    message = ChatMessage.create(channel, {
      id: 1,
      staged: true,
    });
    assert.strictEqual(message.persisted, false);

    message = ChatMessage.create(channel, {
      id: 1,
      staged: false,
    });
    assert.strictEqual(message.persisted, true);
  });
});

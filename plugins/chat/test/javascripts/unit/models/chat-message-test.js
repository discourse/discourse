import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Discourse Chat | Unit | Models | chat-message", function (hooks) {
  setupTest(hooks);

  test(".persisted", function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel();
    let message = ChatMessage.create(channel, { id: null });
    assert.false(message.persisted);

    message = ChatMessage.create(channel, {
      id: 1,
      staged: true,
    });
    assert.false(message.persisted);

    message = ChatMessage.create(channel, {
      id: 1,
      staged: false,
    });
    assert.true(message.persisted);
  });

  test(".url", function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel({ id: 123 });

    let message = ChatMessage.create(channel, { id: 1 });
    assert.strictEqual(message.url, "/chat/c/-/123/1");

    message = ChatMessage.create(channel, { id: 1, thread_id: 456 });
    assert.strictEqual(message.url, "/chat/c/-/123/t/456/1");
  });
});

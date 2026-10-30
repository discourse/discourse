import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Unit | Models | chat-message", function (hooks) {
  setupTest(hooks);

  test("preserves model attribution from the server", function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel();
    const message = ChatMessage.create(channel, {
      id: 1,
      ai_llm_name: "Model 猫",
    });

    assert.strictEqual(message.aiLlmName, "Model 猫");
  });

  test(".cook ignores max_oneboxes_per_post", async function (assert) {
    this.owner.lookup("service:site-settings").max_oneboxes_per_post = 0;
    this.owner.lookup("service:site").markdown_additional_options = {
      chat: {
        limited_pretty_text_features: ["onebox"],
        limited_pretty_text_markdown_rules: ["linkify"],
        hashtag_configurations: { "chat-composer": [] },
        onebox_limit: "none",
      },
    };
    ChatMessage.cookFunction = null;
    const channel = new ChatFabricators(getOwner(this)).channel();
    const message = ChatMessage.create(channel, {
      message: "https://www.example.com",
    });

    await message.cook();
    ChatMessage.cookFunction = null;

    assert.true(message.cooked.includes('class="onebox"'));
  });

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

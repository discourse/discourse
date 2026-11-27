import { hash } from "@ember/helper";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import AiChatModelLabel from "discourse/plugins/discourse-ai/discourse/components/ai-chat-model-label";

module("Integration | Component | AiChatModelLabel", function (hooks) {
  setupRenderingTest(hooks);

  test("hides existing and streamed model labels when disabled", async function (assert) {
    this.siteSettings.ai_bot_show_model_name = false;
    this.message = ChatMessage.create({}, { id: 1, ai_llm_name: "Model <猫>" });

    await render(
      <template>
        <AiChatModelLabel @outletArgs={{hash message=this.message}} />
      </template>
    );

    assert
      .dom(".ai-chat-message__model")
      .doesNotExist("the existing model label is hidden");
    assert.strictEqual(
      this.message.aiLlmName,
      "Model <猫>",
      "existing model metadata is preserved"
    );

    this.message.aiLlmName = "Another model";
    await settled();

    assert
      .dom(".ai-chat-message__model")
      .doesNotExist("streamed updates do not reveal the label");
    assert.strictEqual(
      this.message.aiLlmName,
      "Another model",
      "streamed model metadata is preserved"
    );
  });

  test("shows model attribution when it arrives after the reply", async function (assert) {
    this.message = ChatMessage.create({}, { id: 1 });
    await render(
      <template>
        <AiChatModelLabel @outletArgs={{hash message=this.message}} />
      </template>
    );
    assert.dom(".ai-chat-message__model").doesNotExist();

    this.message.aiLlmName = "Model <猫>";
    await settled();
    assert.dom(".ai-chat-message__model").hasText("Model <猫>");

    this.message.aiLlmName = "Another model";
    await settled();
    assert.dom(".ai-chat-message__model").exists({ count: 1 });
    assert.dom(".ai-chat-message__model").hasText("Another model");
  });
});

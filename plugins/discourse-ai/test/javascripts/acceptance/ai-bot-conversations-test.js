import { triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI Bot - Conversations IME handling", function (needs) {
  needs.user({
    ai_enabled_agents: [],
    ai_enabled_chat_bots: [
      {
        id: 1,
        model_name: "gpt-4",
        username: "gpt-4",
        is_agent: false,
      },
    ],
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/conversations.json", () => {
      return helper.response({
        conversations: [],
        meta: { has_more: false },
      });
    });
  });

  test("does not submit when Enter is pressed during IME composition", async function (assert) {
    await visit("/discourse-ai/ai-bot/conversations");

    const textarea = document.querySelector("#ai-bot-conversations-input");
    textarea.value = "テスト";

    await triggerKeyEvent("#ai-bot-conversations-input", "keydown", "Enter", {
      isComposing: true,
    });

    assert
      .dom("#ai-bot-conversations-input")
      .hasValue("テスト", "textarea value is preserved during IME composition");
  });
});

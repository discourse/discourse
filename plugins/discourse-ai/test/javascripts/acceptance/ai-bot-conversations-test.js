import { fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI Bot - Conversations IME handling", function (needs) {
  let postRequests = 0;

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
    min_personal_message_post_length: 10,
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/conversations.json", () => {
      return helper.response({
        conversations: [],
        meta: { has_more: false },
      });
    });

    server.post("/posts.json", () => {
      postRequests += 1;
      return helper.response({
        id: 1,
        topic_id: 1,
        topic_slug: "ai-conversation",
        post_url: "/t/ai-conversation/1/1",
      });
    });
  });

  test("does not submit when Enter is pressed during IME composition", async function (assert) {
    postRequests = 0;

    await visit("/discourse-ai/ai-bot/conversations");
    await fillIn(
      "#ai-bot-conversations-input",
      "これはテスト入力として十分長い文章です"
    );

    await triggerKeyEvent("#ai-bot-conversations-input", "keydown", "Enter", {
      isComposing: true,
    });

    assert.strictEqual(postRequests, 0, "does not request /posts.json");
  });
});

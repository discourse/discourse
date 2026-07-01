import { fillIn, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const INPUT = "#ai-bot-conversations-input";

acceptance("AI Bot - Conversations IME handling", function (needs) {
  let conversationRequests = 0;

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
    server.get("/discourse-ai/ai-bot/conversations.json", () =>
      helper.response({
        conversations: [],
        meta: { has_more: false },
      })
    );

    server.post("/discourse-ai/ai-bot/conversations.json", () => {
      conversationRequests += 1;
      return helper.response({
        id: 1,
        topic_id: 1,
        topic_slug: "ai-conversation",
        post_url: "/t/ai-conversation/1/1",
      });
    });

    server.get("/t/:slug/:id.json", () => helper.response({}));
  });

  needs.hooks.beforeEach(() => (conversationRequests = 0));

  async function prepareDraft() {
    await visit("/discourse-ai/ai-bot/conversations");
    await fillIn(INPUT, "これはテスト入力として十分長い文章です");
  }

  test("Enter submits the message", async function (assert) {
    await prepareDraft();

    await triggerEvent(INPUT, "keydown", { key: "Enter" });
    await triggerEvent(INPUT, "beforeinput", { inputType: "insertLineBreak" });

    assert.strictEqual(conversationRequests, 1, "submitted once");
  });

  test("Shift+Enter does not submit", async function (assert) {
    await prepareDraft();

    await triggerEvent(INPUT, "keydown", { key: "Enter", shiftKey: true });
    await triggerEvent(INPUT, "beforeinput", { inputType: "insertLineBreak" });

    assert.strictEqual(conversationRequests, 0, "did not submit");
  });

  test("IME-confirming Enter does not submit", async function (assert) {
    await prepareDraft();

    await triggerEvent(INPUT, "keydown", { key: "Enter" });
    await triggerEvent(INPUT, "beforeinput", {
      inputType: "insertCompositionText",
    });

    assert.strictEqual(conversationRequests, 0, "did not submit");
  });
});

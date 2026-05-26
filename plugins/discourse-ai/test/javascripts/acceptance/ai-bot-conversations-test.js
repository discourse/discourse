import {
  fillIn,
  find,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const INPUT = "#ai-bot-conversations-input";

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
    server.get("/discourse-ai/ai-bot/conversations.json", () =>
      helper.response({
        conversations: [],
        meta: { has_more: false },
      })
    );

    server.post("/posts.json", () => {
      postRequests += 1;
      return helper.response({
        id: 1,
        topic_id: 1,
        topic_slug: "ai-conversation",
        post_url: "/t/ai-conversation/1/1",
      });
    });

    server.get("/t/:slug/:id.json", () => helper.response({}));
  });

  needs.hooks.beforeEach(() => (postRequests = 0));

  async function prepareDraft() {
    await visit("/discourse-ai/ai-bot/conversations");
    await fillIn(INPUT, "これはテスト入力として十分長い文章です");
  }

  test("Enter submits the message", async function (assert) {
    await prepareDraft();

    await triggerEvent(INPUT, "keydown", { key: "Enter" });

    assert.strictEqual(postRequests, 1, "submitted once");
  });

  test("Shift+Enter does not submit", async function (assert) {
    await prepareDraft();

    await triggerEvent(INPUT, "keydown", { key: "Enter", shiftKey: true });

    assert.strictEqual(postRequests, 0, "did not submit");
  });

  // Chrome fires the IME-confirming keydown with isComposing=true (compositionend follows)
  test("IME-confirming Enter does not submit (Chrome event order)", async function (assert) {
    await prepareDraft();

    await triggerEvent(INPUT, "keydown", { key: "Enter", isComposing: true });
    await triggerEvent(INPUT, "compositionend");

    assert.strictEqual(postRequests, 0, "did not submit");
  });

  // Safari fires compositionend first, then the IME-confirming keydown in the
  // same task. Dispatch directly so microtasks don't drain between them.
  test("IME-confirming Enter does not submit (Safari event order)", async function (assert) {
    await prepareDraft();

    const el = find(INPUT);
    el.dispatchEvent(new CompositionEvent("compositionend", { bubbles: true }));
    el.dispatchEvent(
      new KeyboardEvent("keydown", {
        key: "Enter",
        bubbles: true,
        cancelable: true,
      })
    );
    await settled();

    assert.strictEqual(postRequests, 0, "did not submit");
  });

  test("Enter after composition has fully settled still submits", async function (assert) {
    await prepareDraft();

    await triggerEvent(INPUT, "compositionend");
    await triggerEvent(INPUT, "keydown", { key: "Enter" });

    assert.strictEqual(postRequests, 1, "submitted once composition is done");
  });
});

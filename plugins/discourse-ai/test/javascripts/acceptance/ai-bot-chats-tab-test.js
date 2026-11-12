import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI Bot - Bot chats tab", function (needs) {
  needs.user({
    ai_enabled_agents: [],
    ai_enabled_chat_bots: [],
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
  });

  needs.pretender((server, helper) => {
    const emptyList = () => helper.response({ topic_list: { topics: [] } });

    server.get("/topics/private-messages/:username.json", emptyList);
    server.get("/discourse-ai/ai-bot/conversations.json", () => {
      return helper.response({
        conversations: [],
        meta: {
          has_more: false,
        },
      });
    });
  });

  test("links to ai-bot conversations and navigates there on click", async function (assert) {
    await visit("/u/eviltrout/messages");

    assert
      .dom(".user-nav__messages-ai-bot-chats")
      .exists("bot chats tab is rendered");
    assert
      .dom(".user-nav__messages-ai-bot-chats a")
      .hasAttribute(
        "href",
        "/discourse-ai/ai-bot/conversations",
        "tab link resolves to the ai-bot conversations route"
      );

    await click(".user-nav__messages-ai-bot-chats a");

    assert.strictEqual(
      currentURL(),
      "/discourse-ai/ai-bot/conversations",
      "transitions to the ai-bot conversations route"
    );
  });

  test("tab is hidden when viewing another user's messages", async function (assert) {
    await visit("/u/charlie/messages");

    assert
      .dom(".user-nav__messages-ai-bot-chats")
      .doesNotExist("bot chats tab is not rendered for other users");
  });
});

acceptance("AI Bot - Bot chats tab - disabled", function (needs) {
  needs.user();

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: false,
  });

  needs.pretender((server, helper) => {
    const emptyList = () => helper.response({ topic_list: { topics: [] } });
    server.get("/topics/private-messages/:username.json", emptyList);
  });

  test("tab is hidden when ai_bot is disabled", async function (assert) {
    await visit("/u/eviltrout/messages");

    assert
      .dom(".user-nav__messages-ai-bot-chats")
      .doesNotExist("bot chats tab is not rendered when ai_bot is disabled");
  });
});

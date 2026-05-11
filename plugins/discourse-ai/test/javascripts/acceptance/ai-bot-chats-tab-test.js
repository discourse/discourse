import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI Bot - Bot chats tab", function (needs) {
  needs.user();

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
  });

  needs.pretender((server, helper) => {
    const emptyList = () => helper.response({ topic_list: { topics: [] } });

    server.get("/topics/private-messages-ai-bot/:username.json", emptyList);
    server.get("/topics/private-messages/:username.json", emptyList);
    server.get("/topics/private-messages-new/:username.json", emptyList);
    server.get("/topics/private-messages-unread/:username.json", emptyList);
    server.get("/topics/private-messages-archive/:username.json", emptyList);
    server.get("/topics/private-messages-sent/:username.json", emptyList);
  });

  test("renders and transitions to bot chats from /messages", async function (assert) {
    await visit("/u/eviltrout/messages");

    assert
      .dom(".user-nav__messages-ai-bot-chats")
      .exists("bot chats tab is rendered");
    assert
      .dom(".user-nav__messages-ai-bot-chats a")
      .hasAttribute(
        "href",
        "/u/eviltrout/messages/ai-bot-chats",
        "tab link resolves to the bot chats route"
      );

    await click(".user-nav__messages-ai-bot-chats a");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/messages/ai-bot-chats",
      "transitions to the bot chats route"
    );
  });

  ["new", "unread", "archive", "sent"].forEach((filter) => {
    test(`tab href resolves on /messages/${filter}`, async function (assert) {
      await visit(`/u/eviltrout/messages/${filter}`);

      assert
        .dom(".user-nav__messages-ai-bot-chats a")
        .hasAttribute(
          "href",
          "/u/eviltrout/messages/ai-bot-chats",
          `tab link resolves on /messages/${filter}`
        );
    });
  });

  test("loads the bot chats route directly", async function (assert) {
    await visit("/u/eviltrout/messages/ai-bot-chats");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/messages/ai-bot-chats",
      "loads bot chats route directly"
    );
    assert
      .dom(".user-nav__messages-ai-bot-chats")
      .exists("bot chats tab is rendered on the bot chats route");
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

import { click, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

// a user only ever has one draft per key, so the message draft is the only
// place a bot recipient can show up in this menu
function draftsResponse(recipients) {
  return {
    drafts: [
      {
        draft_key: "new_private_message",
        sequence: 0,
        draft_username: "eviltrout",
        username: "eviltrout",
        user_id: 1,
        data: JSON.stringify({
          reply: "hello",
          action: "privateMessage",
          title: "A message draft",
          recipients,
          archetypeId: "private_message",
        }),
      },
      {
        draft_key: "topic_280",
        sequence: 0,
        draft_username: "eviltrout",
        username: "eviltrout",
        user_id: 1,
        topic_id: 280,
        title: "A reply draft",
        data: '{"reply":"hello","action":"reply","archetypeId":"regular"}',
      },
    ],
  };
}

acceptance("AI Bot - Drafts dropdown icon", function (needs) {
  let recipients = "gpt4_bot";

  needs.user({
    ai_enabled_chat_bots: [{ id: -110, username: "gpt4_bot" }],
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/drafts.json", () =>
      helper.response(draftsResponse(recipients))
    );
  });

  async function openDraftsMenu() {
    updateCurrentUser({ draft_count: 2 });

    await visit("/");
    await click("button.topic-drafts-menu-trigger");
    await waitFor(".topic-drafts-menu-content");
  }

  test("uses the robot icon for a message draft addressed to a bot", async function (assert) {
    recipients = "gpt4_bot";

    await openDraftsMenu();

    assert
      .dom(".topic-drafts-item:first-child svg.d-icon-robot")
      .exists("bot message draft uses the robot icon");
    assert
      .dom(".topic-drafts-item:last-child svg.d-icon-reply")
      .exists("other drafts keep their icon");
  });

  test("uses the robot icon when a bot is one of several recipients", async function (assert) {
    recipients = "charlie,gpt4_bot";

    await openDraftsMenu();

    assert
      .dom(".topic-drafts-item:first-child svg.d-icon-robot")
      .exists("a message draft including a bot uses the robot icon");
  });

  test("keeps the envelope icon for a message draft without a bot", async function (assert) {
    recipients = "charlie";

    await openDraftsMenu();

    assert
      .dom(".topic-drafts-item:first-child svg.d-icon-envelope")
      .exists("regular message draft keeps the envelope icon");
  });
});

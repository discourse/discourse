import { click, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("AI Bot - Drafts dropdown icon", function (needs) {
  // a user only ever has one draft per key, so the message draft is the only
  // place a bot recipient can show up in this menu
  let recipients;

  needs.user({
    ai_enabled_chat_bots: [{ id: -110, username: "gpt4_bot" }],
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/drafts.json", () =>
      helper.response({
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
        ],
      })
    );
  });

  [
    ["gpt4_bot", "robot"],
    ["charlie,gpt4_bot", "robot"],
    ["charlie", "envelope"],
  ].forEach(([draftRecipients, icon]) => {
    test(`a message draft addressed to ${draftRecipients} uses the ${icon} icon`, async function (assert) {
      recipients = draftRecipients;
      updateCurrentUser({ draft_count: 1 });

      await visit("/");
      await click("button.topic-drafts-menu-trigger");
      await waitFor(".topic-drafts-menu-content");

      assert.dom(`.topic-drafts-item svg.d-icon-${icon}`).exists();
    });
  });
});

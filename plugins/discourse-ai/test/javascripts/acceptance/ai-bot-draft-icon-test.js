import { click, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("AI Bot - Drafts dropdown icon", function (needs) {
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
            data: JSON.stringify({ recipients }),
          },
        ],
      })
    );
  });

  async function openDraftsMenu(draftRecipients) {
    recipients = draftRecipients;
    updateCurrentUser({ draft_count: 1 });

    await visit("/");
    await click("button.topic-drafts-menu-trigger");
    await waitFor(".topic-drafts-menu-content");
  }

  test("uses the robot icon for a draft addressed to a bot", async function (assert) {
    await openDraftsMenu("gpt4_bot");

    assert.dom(".topic-drafts-item svg.d-icon-robot").exists();
  });

  test("uses the robot icon when a bot is one of several recipients", async function (assert) {
    await openDraftsMenu("charlie,gpt4_bot");

    assert.dom(".topic-drafts-item svg.d-icon-robot").exists();
  });

  test("keeps the envelope icon when no recipient is a bot", async function (assert) {
    await openDraftsMenu("charlie");

    assert.dom(".topic-drafts-item svg.d-icon-envelope").exists();
  });
});

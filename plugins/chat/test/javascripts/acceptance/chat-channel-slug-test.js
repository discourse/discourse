import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { chatChannels } from "discourse/plugins/chat/chat-fixtures";

acceptance("Discourse Chat - chat channel slug", function (needs) {
  needs.user({ has_chat_enabled: true, can_chat: true });

  needs.settings({ chat_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
    server.get("/chat/:id/messages.json", () =>
      helper.response({ chat_messages: [], meta: {} })
    );
  });

  test("Replacing title param", async function (assert) {
    await visit("/chat");
    await visit("/chat/channel/11/-");

    assert.equal(currentURL(), "/chat/channel/11/another-category");
  });
});

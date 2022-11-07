import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import fabricators from "../helpers/fabricators";

acceptance("Discourse Chat - delete chat channel modal", function (needs) {
  needs.user({ has_chat_enabled: true, can_chat: true });

  needs.settings({ chat_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/chat/chat_channels.json", () => {
      return helper.response({
        public_channels: [fabricators.chatChannel({ id: 2 })],
        direct_message_channels: [],
      });
    });

    server.get("/chat/chat_channels/:id", (request) => {
      return helper.response(
        fabricators.chatChannel({ id: request.params.id })
      );
    });

    server.get("/chat/:id/messages.json", () => {
      return helper.response({ meta: {}, chat_messages: [] });
    });

    server.delete("/chat/chat_channels/:id.json", () => {
      return helper.response({});
    });
  });

  test("Redirection after deleting a channel", async function (assert) {
    await visit("chat/channel/1/my-category-title/info/settings");
    await click(".delete-btn");
    await fillIn("#channel-delete-confirm-name", "My category title");
    await click("#chat-confirm-delete-channel");

    assert.equal(currentURL(), "/chat/channel/2/my-category-title");
  });
});

import {
  acceptance,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  chatChannels,
  generateChatView,
} from "discourse/plugins/chat/chat-fixtures";

function setupPretenders(server, helper) {
  server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
  server.get("/chat/:chat_channel_id/messages.json", () =>
    helper.response(generateChatView(loggedInUser()))
  );
  server.get("/chat/emojis.json", () =>
    helper.response({ favorites: [{ name: "grinning" }] })
  );
  server.put("/chat/:id/react/:message_id.json", helper.response);
}

acceptance("Discourse Chat - Chat Message", function (needs) {
  needs.user({ has_chat_enabled: true });
  needs.settings({ chat_enabled: true });
  needs.pretender((server, helper) => setupPretenders(server, helper));

  test("when reacting to a message using inline reaction", async function (assert) {
    const emojiReactionStore = this.container.lookup(
      "service:chat-emoji-reaction-store"
    );

    assert.deepEqual(emojiReactionStore.favorites, []);

    await visit("/chat/channel/4/public-category");
    await click(
      `.chat-message-container[data-id="176"] .chat-message-reaction[data-emoji-name="heart"]`
    );

    assert.deepEqual(
      emojiReactionStore.favorites,
      ["heart"],
      "it tracks the emoji"
    );

    await click(
      `.chat-message-container[data-id="176"] .chat-message-reaction[data-emoji-name="heart"]`
    );

    assert.deepEqual(
      emojiReactionStore.favorites,
      ["heart"],
      "it doesn’t untrack when removing the reaction"
    );
  });

  test("when reacting to a message using emoji picker reaction", async function (assert) {
    const emojiReactionStore = this.container.lookup(
      "service:chat-emoji-reaction-store"
    );

    assert.deepEqual(emojiReactionStore.favorites, []);

    await visit("/chat/channel/4/public-category");
    await triggerEvent(".chat-message-container[data-id='176']", "mouseenter");
    await click(".chat-msgactions-hover .react-btn");
    await click(`[data-emoji="grinning"]`);

    assert.deepEqual(
      emojiReactionStore.favorites,
      ["grinning"],
      "it tracks the emoji"
    );

    await click(
      `.chat-message-container[data-id="176"] .chat-message-reaction[data-emoji-name="grinning"]`
    );

    assert.deepEqual(
      emojiReactionStore.favorites,
      ["grinning"],
      "it doesn’t untrack when removing the reaction"
    );
  });
});

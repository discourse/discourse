import { visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import {
  chatChannels,
  generateChatView,
} from "discourse/plugins/chat/chat-fixtures";
import {
  acceptance,
  exists,
  loggedInUser,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { test } from "qunit";

const baseChatPretenders = (server, helper) => {
  server.get("/chat/:chatChannelId/messages.json", () =>
    helper.response(generateChatView(loggedInUser()))
  );
  server.post("/chat/:chatChannelId.json", () => {
    return helper.response({ success: "OK" });
  });
  server.get("/chat/lookup/:messageId.json", () =>
    helper.response(generateChatView(loggedInUser()))
  );
  server.post("/uploads/lookup-urls", () => {
    return helper.response([]);
  });
  server.get("/chat/chat_channels.json", () => {
    let copy = cloneJSON(chatChannels);
    let modifiedChannel = copy.public_channels.find((pc) => pc.id === 4);
    modifiedChannel.current_user_membership.unread_count = 2;
    return helper.response(copy);
  });

  // this is only fetched on channel-status change; when expanding on
  // this test we may want to introduce some counter to track when
  // this is fetched if we want to return different statuses
  server.get("/chat/chat_channels/4", () => {
    let channel = cloneJSON(
      chatChannels.public_channels.find((pc) => pc.id === 4)
    );
    channel.status = "archived";
    return helper.response(channel);
  });
};

acceptance(
  "Discourse Chat - Respond to /chat/channel-status archive message",
  function (needs) {
    needs.user({
      admin: true,
      moderator: true,
      username: "tomtom",
      id: 1,
      can_chat: true,
      has_chat_enabled: true,
    });

    needs.settings({
      chat_enabled: true,
      chat_allow_archiving_channels: true,
      enable_sidebar: false,
    });

    needs.pretender((server, helper) => {
      baseChatPretenders(server, helper);
    });

    test("it clears any unread messages in the sidebar for the archived channel", async function (assert) {
      await visit("/chat/channel/4/public-category");
      assert.ok(
        exists(
          '.chat-channel-row[data-chat-channel-id="4"] .chat-channel-unread-indicator'
        ),
        "unread indicator shows for channel"
      );

      await publishToMessageBus("/chat/channel-status", {
        chat_channel_id: 4,
        status: "archived",
      });
      assert.notOk(
        exists(
          '.chat-channel-row[data-chat-channel-id="4"] .chat-channel-unread-indicator'
        ),
        "unread indicator should not show after archive status change"
      );
    });

    test("it changes the channel status in the header to archived", async function (assert) {
      await visit("/chat/channel/4/Topic");

      assert.notOk(
        exists(".chat-channel-title-with-status .chat-channel-status"),
        "channel status does not show if the channel is open"
      );

      await publishToMessageBus("/chat/channel-status", {
        chat_channel_id: 4,
        status: "archived",
      });
      assert.strictEqual(
        query(".chat-channel-status").innerText.trim(),
        I18n.t("chat.channel_status.archived_header"),
        "channel status changes to archived"
      );
    });
  }
);

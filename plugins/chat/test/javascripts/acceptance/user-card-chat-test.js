import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import {
  acceptance,
  exists,
  loggedInUser,
  query,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import {
  chatChannels,
  directMessageChannels,
  generateChatView,
} from "discourse/plugins/chat/chat-fixtures";
import { test } from "qunit";

acceptance("Discourse Chat - User card test", function (needs) {
  needs.user({
    admin: false,
    moderator: false,
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
    server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
    server.get("/chat/chat_channels/:channelId.json", () =>
      helper.response(helper.response(directMessageChannels[0]))
    );
    server.get("/chat/:chatChannelId/messages.json", () =>
      helper.response(generateChatView(loggedInUser()))
    );
    server.post("/chat/direct_messages/create.json", () => {
      return helper.response({
        chat_channel: {
          chat_channels: [],
          chatable: {
            users: [
              {
                username: "hawk",
                id: 2,
                name: "hawk",
                avatar_template:
                  "/letter_avatar_proxy/v3/letter/t/41988e/{size}.png",
              },
            ],
          },
          chatable_id: 16,
          chatable_type: "DirectMessage",
          chatable_url: null,
          id: 75,
          title: "@hawk",
          last_message_sent_at: "2021-11-08T21:26:05.710Z",
          current_user_membership: {
            last_read_message_id: null,
            unread_count: 0,
            unread_mentions: 0,
          },
        },
      });
    });
    let cardResponse = cloneJSON(userFixtures["/u/charlie/card.json"]);
    cardResponse.user.can_chat_user = true;
    server.get("/u/hawk/card.json", () => helper.response(cardResponse));
  });
  needs.settings({
    chat_enabled: true,
  });

  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatService", {
      get: () => this.container.lookup("service:chat"),
    });
    Object.defineProperty(this, "appEvents", {
      get: () => this.container.lookup("service:appEvents"),
    });
  });

  test("user card has chat button that opens the correct channel", async function (assert) {
    this.chatService.set("sidebarActive", false);
    await visit("/");
    await click(".header-dropdown-toggle.open-chat");
    await click(".chat-channel-row.chat-channel-9");
    await click("[data-user-card='hawk']");

    assert.ok(exists(".user-card-chat-btn"));

    await click(".user-card-chat-btn");

    assert.ok(visible(".topic-chat-float-container"), "chat float is open");
    assert.ok(query(".topic-chat-container").classList.contains("channel-75"));
  });
});

acceptance(
  "Discourse Chat - Anon user viewing user card test",
  function (needs) {
    needs.settings({
      chat_enabled: true,
    });

    test("user card has no chat button", async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click('a[data-user-card="charlie"]');

      assert.notOk(
        exists(".user-card-chat-btn"),
        "anon user should not be able to chat with anyone via the user card"
      );
    });
  }
);

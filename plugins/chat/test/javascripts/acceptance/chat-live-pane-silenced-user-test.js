import { visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Discourse Chat - Chat live pane", function (needs) {
  needs.user({
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });
  needs.settings({
    chat_enabled: true,
    navigation_menu: "legacy",
  });
  needs.pretender((server, helper) => {
    server.get("/chat/:chatChannelId/messages.json", () =>
      helper.response({
        meta: {
          can_flag: true,
          user_silenced: true,
        },
        chat_messages: [
          {
            id: 1,
            message: "hi",
            cooked: "<p>hi</p>",
            excerpt: "hi",
            created_at: "2021-07-20T08:14:16.950Z",
            flag_count: 0,
            user: {
              avatar_template:
                "/letter_avatar_proxy/v4/letter/t/a9a28c/{size}.png",
              id: 1,
              name: "Tomtom",
              username: "tomtom",
            },
            reactions: {
              heart: {
                count: 1,
                reacted: false,
                users: [{ id: 99, username: "im-penar" }],
              },
            },
          },
        ],
      })
    );

    server.get("/chat/chat_channels.json", () =>
      helper.response({
        public_channels: [
          {
            id: 1,
            title: "something",
            current_user_membership: { following: true },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
        ],
        direct_message_channels: [],
        message_bus_last_ids: {
          channel_metadata: 0,
          channel_edits: 0,
          channel_status: 0,
          new_channel: 0,
          user_tracking_state: 0,
        },
      })
    );

    server.get("/chat/chat_channels/:chatChannelId", () =>
      helper.response({
        id: 1,
        title: "something",
        current_user_membership: { following: true },
      })
    );
  });

  test("Textarea and message interactions are disabled when user is silenced", async function (assert) {
    await visit("/chat/channel/1/cat");
    assert.equal(query(".chat-composer-input").disabled, true);
    assert.notOk(exists(".chat-message-actions-container"));
    assert.notOk(exists(".chat-message-react-btn"));
  });
});

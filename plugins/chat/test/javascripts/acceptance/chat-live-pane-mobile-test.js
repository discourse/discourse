import { click, visit } from "@ember/test-helpers";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Discourse Chat - Chat live pane mobile", function (needs) {
  needs.mobileView();
  needs.user({
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });
  needs.settings({
    chat_enabled: true,
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
          },
          {
            id: 2,
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
          },
        ],
      })
    );

    server.get("/chat/chat_channels.json", () =>
      helper.response({
        public_channels: [],
        direct_message_channels: [],
      })
    );

    server.get("/chat/chat_channels/:chatChannelId", () =>
      helper.response({ id: 1, title: "something" })
    );
  });

  test("touching message", async function (assert) {
    await visit("/chat/channel/1/cat");

    const messageExists = (id) => {
      return exists(
        `.chat-message-container[data-id='${id}'] .chat-message-selected`
      );
    };

    assert.notOk(messageExists(1));
    assert.notOk(messageExists(2));

    await click(".chat-message-container[data-id='1']");

    assert.notOk(messageExists(1), "it doesn’t select the touched message");
  });
});

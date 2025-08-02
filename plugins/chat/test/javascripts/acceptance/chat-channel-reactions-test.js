import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

const category = { id: 1, color: "ff0000", name: "category1" };
const messageId = 1891;
const message = {
  id: messageId,
  message: "Lorem ipsum!",
  cooked: `<p>Lorem ipsum!</p>`,
  created_at: "2020-08-04T15:00:00.000Z",
  user: {
    id: 1,
    username: "jesse",
  },
};

acceptance("Discourse Chat - Channel Reactions", function (needs) {
  needs.user({ has_chat_enabled: true });
  needs.settings({ chat_enabled: true });

  needs.hooks.beforeEach(function () {
    pretender.get("/chat/api/me/channels", () =>
      response({
        direct_message_channels: [],
        public_channels: [
          {
            id: 11,
            title: "My channel",
            chatable_id: 1,
            chatable_type: "Category",
            meta: { message_bus_last_ids: {} },
            current_user_membership: {
              following: true,
              last_read_message_id: messageId,
            },
            chatable: category,
          },
        ],
        meta: { message_bus_last_ids: {} },
        tracking: {
          channel_tracking: {
            11: { unread_count: 0, mention_count: 0 },
          },
          thread_tracking: {},
        },
      })
    );

    pretender.get(`/chat/api/channels/11/messages`, () =>
      response({
        messages: [message],
        meta: { can_delete_self: true },
      })
    );
  });

  test("shows the reaction button with the count", async function (assert) {
    await visit("/chat/c/another-category/11");

    await Promise.all([
      publishToMessageBus("/chat/11", {
        type: "reaction",
        emoji: "rocket",
        chat_message_id: messageId,
        action: "add",
        user: { id: 5, username: "alice" },
      }),
      publishToMessageBus("/chat/11", {
        type: "reaction",
        emoji: "rocket",
        chat_message_id: messageId,
        action: "add",
        user: { id: 6, username: "bob" },
      }),
    ]);

    assert
      .dom(".chat-message-reaction[data-emoji-name='rocket'] .count")
      .hasText("2");
  });
});

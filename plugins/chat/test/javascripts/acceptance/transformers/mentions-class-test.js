import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const category = { id: 1, color: "ff0000", name: "category1" };
const messageId = 1891;
const message = {
  id: messageId,
  mentioned_users: [{ id: 19, username: "eviltrout" }],
  message: "Lorem ipsum! @eviltrout",
  cooked: `<p>Lorem ipsum! <a class="mention" href="/u/eviltrout">@eviltrout</a></p>`,
  created_at: "2020-08-04T15:00:00.000Z",
  user: {
    id: 1,
    username: "jesse",
  },
};

acceptance("mentions-class transformer", function (needs) {
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
      response({ messages: [message] })
    );
  });

  test("shows the reaction button with the count", async function (assert) {
    await visit("/chat/c/another-category/11");

    assert.dom(".mention[href='/u/eviltrout']").hasClass("--current");
  });
});

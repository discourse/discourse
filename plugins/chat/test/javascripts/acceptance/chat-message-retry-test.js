import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const CHANNEL_ID = 11;

acceptance("Retry message on send failure", function (needs) {
  needs.user({ has_chat_enabled: true });
  needs.settings({ chat_enabled: true });

  let sendAttempt;

  needs.hooks.beforeEach(function () {
    sendAttempt = 0;

    pretender.get("/chat/api/me/channels", () =>
      response({
        direct_message_channels: [],
        public_channels: [
          {
            id: CHANNEL_ID,
            title: "My channel",
            chatable_type: "Category",
            meta: { message_bus_last_ids: {} },
            current_user_membership: { following: true },
            chatable: { color: "ff0000" },
          },
        ],
        meta: { message_bus_last_ids: {} },
        tracking: {},
      })
    );

    pretender.get(`/chat/api/channels/${CHANNEL_ID}/messages`, () =>
      response({ messages: [], meta: {} })
    );

    pretender.post(`/chat/api/channels/${CHANNEL_ID}/drafts`, () =>
      response({})
    );

    pretender.post(`/chat/${CHANNEL_ID}`, () => {
      sendAttempt += 1;
      return sendAttempt === 1
        ? response(500, {})
        : response({ success: "OK" });
    });
  });

  test("shows a retry button when sending fails and resends on click", async function (assert) {
    await visit(`/chat/c/-/${CHANNEL_ID}`);
    await fillIn(".chat-composer__input", "hello there");
    await click(".chat-composer .-send");

    assert
      .dom(".chat-message-error__retry-btn")
      .exists("shows the retry button after a network error");

    await click(".chat-message-error__retry-btn");

    assert
      .dom(".chat-message-error__retry-btn")
      .doesNotExist("clears the retry button after a successful resend");
  });
});

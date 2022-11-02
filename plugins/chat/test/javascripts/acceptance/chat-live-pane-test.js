import { click, fillIn, tap, triggerEvent, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  loggedInUser,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { generateChatView } from "discourse/plugins/chat/chat-fixtures";

function buildMessage(messageId) {
  return {
    id: messageId,
    message: "hi",
    cooked: "<p>hi</p>",
    excerpt: "hi",
    created_at: "2021-07-20T08:14:16.950Z",
    flag_count: 0,
    user: {
      avatar_template: "/letter_avatar_proxy/v4/letter/t/a9a28c/{size}.png",
      id: 1,
      name: "Tomtom",
      username: "tomtom",
    },
  };
}

acceptance(
  "Discourse Chat - Chat live pane - viewing old messages",
  function (needs) {
    needs.user({
      username: "eviltrout",
      id: 1,
      can_chat: true,
      has_chat_enabled: true,
    });
    needs.settings({
      chat_enabled: true,
    });

    let loadAllMessages = false;

    needs.hooks.beforeEach(() => {
      loadAllMessages = false;
    });

    needs.pretender((server, helper) => {
      const firstPageMessages = [];

      for (let i = 0; i < 50; i++) {
        firstPageMessages.push(buildMessage(i + 1));
      }

      server.get("/chat/:chatChannelId/messages.json", () => {
        if (loadAllMessages) {
          const updatedPage = [...firstPageMessages];
          updatedPage.shift();
          updatedPage.shift();
          updatedPage.push(buildMessage(51));
          updatedPage.push(buildMessage(52));

          return helper.response({
            meta: {
              can_load_more_future: false,
            },
            chat_messages: updatedPage,
          });
        } else {
          return helper.response({
            meta: {
              can_flag: true,
              user_silenced: false,
              can_load_more_future: true,
            },
            chat_messages: firstPageMessages,
          });
        }
      });

      server.get("/chat/chat_channels.json", () =>
        helper.response({
          public_channels: [
            {
              id: 1,
              title: "something",
              current_user_membership: { following: true },
            },
          ],
          direct_message_channels: [],
        })
      );

      server.get("/chat/chat_channels/:chatChannelId", () =>
        helper.response({ id: 1, title: "something" })
      );

      server.post("/chat/drafts", () => {
        return helper.response([]);
      });

      server.post("/chat/:chatChannelId.json", () => {
        return helper.response({ success: "OK" });
      });
    });

    test("doesn't create a gap in history by adding new messages", async function (assert) {
      await visit("/chat/channel/1/cat");

      await publishToMessageBus("/chat/1", {
        type: "sent",
        chat_message: {
          id: 51,
          cooked: "<p>hello!</p>",
          user: {
            id: 2,
          },
        },
      });

      assert.notOk(exists(`.chat-message-container[data-id='${51}']`));
    });

    test("It continues to handle other message types", async function (assert) {
      await visit("/chat/channel/1/cat");

      await publishToMessageBus("/chat/1", {
        action: "add",
        user: { id: 77, username: "notTomtom" },
        emoji: "cat",
        type: "reaction",
        chat_message_id: 1,
      });

      assert.ok(exists(`.chat-message-reaction[data-emoji-name="cat"]`));
    });

    test("Sending a new message when there are still unloaded ones will fetch them", async function (assert) {
      await visit("/chat/channel/1/cat");

      assert.notOk(exists(`.chat-message-container[data-id='${51}']`));

      loadAllMessages = true;
      const composerInput = query(".chat-composer-input");
      await fillIn(composerInput, "test text");
      await click(".send-btn");

      assert.ok(exists(`.chat-message-container[data-id='${51}']`));
      assert.ok(exists(`.chat-message-container[data-id='${52}']`));
    });

    test("Clicking the arrow button jumps to the bottom of the channel", async function (assert) {
      await visit("/chat/channel/1/cat");

      assert.notOk(exists(`.chat-message-container[data-id='${51}']`));
      const scrollerEl = document.querySelector(".chat-messages-scroll");
      scrollerEl.scrollTop = -500; // Scroll up a bit
      const initialPosition = scrollerEl.scrollTop;
      await triggerEvent(".chat-messages-scroll", "scroll", {
        forceShowScrollToBottom: true,
      });

      loadAllMessages = true;
      await click(".chat-scroll-to-bottom");

      assert.ok(exists(`.chat-message-container[data-id='${51}']`));
      assert.ok(exists(`.chat-message-container[data-id='${52}']`));

      assert.ok(
        scrollerEl.scrollTop > initialPosition,
        "Scrolled to the bottom"
      );
    });
  }
);

acceptance(
  "Discourse Chat - Chat live pane - handling 429 errors",
  function (needs) {
    needs.user({
      username: "eviltrout",
      id: 1,
      has_chat_enabled: true,
    });
    needs.settings({
      chat_enabled: true,
    });

    needs.pretender((server, helper) => {
      server.get("/chat/:chatChannelId/messages.json", () => {
        return helper.response(429);
      });

      server.get("/chat/chat_channels.json", () =>
        helper.response({
          public_channels: [
            {
              id: 1,
              title: "something",
              current_user_membership: { following: true },
            },
          ],
          direct_message_channels: [],
        })
      );

      server.get("/chat/chat_channels/:chatChannelId", () =>
        helper.response({ id: 1, title: "something" })
      );

      server.post("/chat/drafts", () => {
        return helper.response([]);
      });

      server.post("/chat/:chatChannelId.json", () => {
        return helper.response({ success: "OK" });
      });
    });

    test("Handles 429 errors by displaying an alert", async function (assert) {
      await visit("/chat/channel/1/cat");

      assert.ok(exists(".dialog-content"), "We displayed a 429 error");
      await click(".dialog-footer .btn-primary");
    });
  }
);

acceptance(
  "Discourse Chat - Chat live pane - handling 404 errors",
  function (needs) {
    needs.user({
      username: "eviltrout",
      id: 1,
      has_chat_enabled: true,
    });

    needs.settings({ chat_enabled: true });

    needs.pretender((server, helper) => {
      server.get("/chat/:chatChannelId/messages.json", () => {
        return helper.response(404);
      });

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

    test("Handles 404 errors by displaying an alert", async function (assert) {
      await visit("/chat/channel/1/cat");

      assert.ok(exists(".dialog-content"), "it displays a 404 error");
      await click(".dialog-footer .btn-primary");
    });
  }
);

acceptance(
  "Discourse Chat - Chat live pane (mobile) - actions menu",
  function (needs) {
    needs.user({ has_chat_enabled: true });

    needs.settings({ chat_enabled: true });

    needs.mobileView();

    needs.pretender((server, helper) => {
      server.get("/chat/:chatChannelId/messages.json", () =>
        helper.response(generateChatView(loggedInUser()))
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

    test("when expanding and collapsing the actions menu", async function (assert) {
      await visit("/chat/channel/1/cat");
      const message = query(".chat-message-container");
      await tap(message);

      assert.ok(exists(".chat-msgactions-backdrop"));

      await tap(".collapse-area");

      assert.notOk(exists(".chat-msgactions-backdrop"));
    });
  }
);

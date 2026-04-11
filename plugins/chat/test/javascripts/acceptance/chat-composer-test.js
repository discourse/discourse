import {
  click,
  fillIn,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { skip, test } from "qunit";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import {
  baseChatPretenders,
  chatChannelPretender,
} from "../helpers/chat-pretenders";

const GROUP_NAME = "group1";

acceptance("Discourse Chat - Composer", function (needs) {
  needs.user({ has_chat_enabled: true });
  needs.settings({
    chat_enabled: true,
    enable_rich_text_paste: true,
    enable_emoji: true,
  });
  needs.pretender((server, helper) => {
    baseChatPretenders(server, helper);
    chatChannelPretender(server, helper);
    server.get("/chat/:id/messages.json", () =>
      helper.response({ chat_messages: [], meta: {} })
    );
    server.get("/emojis.json", () =>
      helper.response({ favorites: [{ name: "grinning" }] })
    );
    server.post("/chat/drafts", () => {
      return helper.response([]);
    });

    server.get("/chat/api/mentions/groups.json", () => {
      return helper.response({
        unreachable: [GROUP_NAME],
        over_members_limit: [],
        invalid: [],
      });
    });
  });

  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatService", {
      get: () => this.container.lookup("service:chat"),
    });
  });

  skip("when pasting html in composer", async function (assert) {
    await visit("/chat/c/another-category/11");

    await triggerEvent(".chat-composer__input", "paste", {
      bubbles: true,
      clipboardData: {
        types: ["text/html"],
        getData: (type) => {
          if (type === "text/html") {
            return "<a href>Foo</a>";
          }
        },
      },
    });

    assert.dom(".chat-composer__input").hasValue("Foo");
  });
});

let sendAttempt = 0;
acceptance("Discourse Chat - Composer - unreliable network", function (needs) {
  needs.user({ id: 1, has_chat_enabled: true });
  needs.settings({
    chat_enabled: true,
    enable_emoji: true,
  });
  needs.pretender((server, helper) => {
    chatChannelPretender(server, helper);
    server.get("/chat/:id/messages.json", () =>
      helper.response({ chat_messages: [], meta: {} })
    );
    server.post("/chat/drafts", () => helper.response(500, {}));
    server.post("/chat/:id.json", () => {
      sendAttempt += 1;
      return sendAttempt === 1
        ? helper.response(500, {})
        : helper.response({ success: true });
    });
  });

  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatService", {
      get: () => this.container.lookup("service:chat"),
    });
  });

  needs.hooks.afterEach(function () {
    sendAttempt = 0;
  });

  skip("Sending a message with unreliable network", async function (assert) {
    await visit("/chat/c/-/11");
    await fillIn(".chat-composer__input", "network-error-message");
    await click(".chat-composer-button.-send");

    assert
      .dom(".chat-message-container[data-id='1'] .retry-staged-message-btn")
      .exists("it adds a retry button");

    await fillIn(".chat-composer__input", "network-error-message");
    await click(".chat-composer-button.-send");
    await publishToMessageBus(`/chat/11`, {
      type: "sent",
      staged_id: 1,
      chat_message: {
        cooked: "network-error-message",
        id: 175,
        user: { id: 1 },
      },
    });

    assert
      .dom(".chat-message-container[data-id='1'] .retry-staged-message-btn")
      .doesNotExist("it removes the staged message");
    assert
      .dom(".chat-message-container[data-id='175']")
      .exists("it sends the message");
    assert.dom(".chat-composer__input").hasNoValue("clears the input");
  });

  skip("Draft with unreliable network", async function (assert) {
    await visit("/chat/c/-/11");
    this.chatService.set("isNetworkUnreliable", true);
    await settled();

    assert
      .dom(".chat-composer__unreliable-network")
      .exists("it displays a network error icon");
  });
});

acceptance(
  "Discourse Chat - Composer - draft cleared on send",
  function (needs) {
    needs.user({ has_chat_enabled: true });
    needs.settings({ chat_enabled: true });

    needs.pretender((server, helper) => {
      server.get("/chat/api/me/channels", () =>
        helper.response({
          direct_message_channels: [],
          public_channels: [
            {
              id: 11,
              title: "General",
              chatable_id: 1,
              chatable_type: "Category",
              chatable: { id: 1, color: "ff0000", name: "general" },
              current_user_membership: { following: true },
              meta: {
                message_bus_last_ids: {
                  new_mentions: 0,
                  new_messages: 0,
                  kick: 0,
                },
              },
            },
          ],
          meta: { message_bus_last_ids: {} },
          tracking: {
            channel_tracking: { 11: { unread_count: 0, mention_count: 0 } },
            thread_tracking: {},
          },
        })
      );

      server.get("/chat/api/channels/11/messages", () =>
        helper.response({
          messages: [],
          meta: { can_delete_self: false },
        })
      );

      server.post("/chat/11", () => helper.response({ success: true }));
      server.post("/chat/api/channels/11/drafts", () => helper.response({}));
    });

    needs.hooks.beforeEach(function () {
      Object.defineProperty(this, "chatDraftsManager", {
        get: () => this.container.lookup("service:chat-drafts-manager"),
      });
    });

    test("clears the draft from chatDraftsManager when a message is sent", async function (assert) {
      await visit("/chat/c/another-category/11");

      await fillIn(".chat-composer__input", "hello world");

      assert.notStrictEqual(
        this.chatDraftsManager.get(11),
        undefined,
        "draft is saved to chatDraftsManager after typing"
      );

      await click(".chat-composer-button.-send");

      assert.strictEqual(
        this.chatDraftsManager.get(11),
        undefined,
        "draft is removed from chatDraftsManager after sending"
      );
    });
  }
);

import {
  click,
  fillIn,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { skip } from "qunit";
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
  needs.settings({ chat_enabled: true, enable_rich_text_paste: true });
  needs.pretender((server, helper) => {
    baseChatPretenders(server, helper);
    chatChannelPretender(server, helper);
    server.get("/chat/:id/messages.json", () =>
      helper.response({ chat_messages: [], meta: {} })
    );
    server.get("/chat/emojis.json", () =>
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
  needs.settings({ chat_enabled: true });
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

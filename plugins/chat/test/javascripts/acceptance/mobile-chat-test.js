import {
  acceptance,
  exists,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, visit } from "@ember/test-helpers";
import {
  chatChannels,
  generateChatView,
} from "discourse/plugins/chat/chat-fixtures";
import { test } from "qunit";

acceptance("Discourse Chat - Mobile test", function (needs) {
  needs.user({ can_chat: true, has_chat_enabled: true });

  needs.mobileView();

  needs.pretender((server, helper) => {
    server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
    server.get("/chat/:id/messages.json", () =>
      helper.response(generateChatView(loggedInUser()))
    );
    server.get("/u/search/users", () => {
      return helper.response([]);
    });
  });

  needs.settings({
    chat_enabled: true,
  });

  test("Chat index route shows channels list", async function (assert) {
    await visit("/latest");
    await click(".header-dropdown-toggle.open-chat");
    assert.equal(currentURL(), "/chat");
    assert.ok(exists(".channels-list"));
    await click(".chat-channel-row.chat-channel-7");
    assert.notOk(exists(".chat-full-screen-button"));
  });

  test("Chat new personal chat buttons", async function (assert) {
    await visit("/chat");
    await click(".new-dm.btn-floating");
    assert.strictEqual(
      currentURL(),
      "/chat/draft-channel",
      "Clicking the floating + button opens the new chat screen"
    );

    await click(".chat-draft-header__btn");
    assert.strictEqual(
      currentURL(),
      "/chat",
      "Clicking the left arrow button returns to the channels list"
    );
  });
});

import { skip, test } from "qunit";
import {
  click,
  currentURL,
  tap,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import {
  acceptance,
  exists,
  loggedInUser,
  query,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import {
  chatChannels,
  generateChatView,
} from "discourse/plugins/chat/chat-fixtures";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const quoteResponse = {
  markdown: `[chat quote="martin-chat;3875498;2022-02-04T01:12:15Z" channel="The Beam Discussions" channelId="1234"]
  an extremely insightful response :)
  [/chat]`,
};

function setupPretenders(server, helper) {
  server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
  server.post(`/chat/4/quote.json`, () => helper.response(quoteResponse));
  server.post(`/chat/7/quote.json`, () => helper.response(quoteResponse));
  server.get("/chat/:chat_channel_id/messages.json", () =>
    helper.response(generateChatView(loggedInUser()))
  );
  server.post("/uploads/lookup-urls", () => {
    return helper.response([]);
  });
}

acceptance("Discourse Chat | Copying messages", function (needs) {
  needs.user({
    admin: false,
    moderator: false,
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });

  needs.settings({
    chat_enabled: true,
  });

  needs.pretender((server, helper) => {
    setupPretenders(server, helper);
  });

  test("it copies the quote and shows a message", async function (assert) {
    await visit("/chat/channel/7/Bug");
    assert.ok(exists(".chat-message-container"));

    const firstMessage = query(".chat-message-container");
    await triggerEvent(firstMessage, "mouseenter");
    const dropdown = selectKit(
      `.chat-message-actions-container[data-id="${firstMessage.dataset.id}"] .more-buttons`
    );
    await dropdown.expand();
    await dropdown.selectRowByValue("selectMessage");
    assert.ok(firstMessage.classList.contains("selecting-messages"));

    const copyButton = query(".chat-live-pane #chat-copy-btn");
    assert.equal(
      copyButton.disabled,
      false,
      "button is enabled as a message is selected"
    );

    await click(firstMessage.querySelector("input[type='checkbox']"));
    assert.equal(
      copyButton.disabled,
      true,
      "button is disabled when no messages are selected"
    );

    await click(firstMessage.querySelector("input[type='checkbox']"));
    await click("#chat-copy-btn");
    assert.ok(exists(".chat-selection-message"), "shows the message");
  });
});

acceptance("Discourse Chat | Quoting in composer", async function (needs) {
  needs.user({
    admin: false,
    moderator: false,
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });

  needs.settings({
    chat_enabled: true,
  });

  needs.pretender((server, helper) => {
    setupPretenders(server, helper);
  });

  skip("it opens the composer for the topic and pastes in the quote", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(".header-dropdown-toggle.open-chat");
    assert.ok(visible(".chat-drawer-container"), "chat drawer is open");
    assert.ok(exists(".chat-message-container"));

    const firstMessage = query(".chat-message-container");
    await triggerEvent(firstMessage, "mouseenter");
    const dropdown = selectKit(".chat-message-container .more-buttons");
    await dropdown.expand();
    await dropdown.selectRowByValue("selectMessage");
    assert.ok(firstMessage.classList.contains("selecting-messages"));

    await click("#chat-quote-btn");
    assert.ok(exists("#reply-control.composer-action-reply"));
    assert.strictEqual(
      query(".composer-action-title .action-title").innerText,
      "Internationalization / localization"
    );
    assert.strictEqual(
      query("textarea.d-editor-input").value,
      quoteResponse.markdown
    );
  });
});

acceptance("Discourse Chat | Quoting on mobile", async function (needs) {
  needs.user({
    admin: false,
    moderator: false,
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });

  needs.settings({
    chat_enabled: true,
  });

  needs.pretender((server, helper) => {
    setupPretenders(server, helper);
  });

  needs.mobileView();

  skip("it opens the chatable, opens the composer, and pastes the markdown in", async function (assert) {
    await visit("/chat/channel/7/Bug");
    assert.ok(exists(".chat-message-container"));

    const firstMessage = query(".chat-message-container");
    await tap(firstMessage);
    await click(".chat-message-action-item[data-id='selectMessage'] button");
    assert.ok(firstMessage.classList.contains("selecting-messages"));

    await click("#chat-quote-btn");

    assert.equal(currentURL(), "/c/bug/1", "navigates to the chatable url");
    assert.ok(
      exists("#reply-control.composer-action-createTopic"),
      "the composer opens"
    );
    assert.strictEqual(
      query("textarea.d-editor-input").value,
      quoteResponse.markdown,
      "the composer has the markdown"
    );
    assert.strictEqual(
      selectKit(".category-chooser").header().value(),
      "1",
      "it fills category selector with the right category"
    );
  });
});

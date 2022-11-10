import { test } from "qunit";
import { click, fillIn, tap, triggerEvent, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  loggedInUser,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import {
  chatChannels,
  generateChatView,
} from "discourse/plugins/chat/chat-fixtures";

function setupPretenders(server, helper) {
  server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
  server.get("/chat/:chat_channel_id/messages.json", () =>
    helper.response(generateChatView(loggedInUser()))
  );
  server.post("/uploads/lookup-urls", () => {
    return helper.response([]);
  });
}

acceptance("Discourse Chat | bookmarking | desktop", function (needs) {
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
    server.post("/bookmarks", () => helper.response({ id: 1, success: "OK" }));
  });

  test("can bookmark a message with reminder from the quick actions menu", async function (assert) {
    await visit("/chat/channel/4/public-category");
    assert.ok(exists(".chat-message-container"));
    const message = query(".chat-message-container");

    await triggerEvent(message, "mouseenter");
    await click(".chat-message-actions .bookmark-btn");
    assert.ok(
      exists("#bookmark-reminder-modal"),
      "it shows the bookmark modal"
    );
    await fillIn("input#bookmark-name", "Check this out later");
    await click("#tap_tile_next_month");
    assert.ok(
      message.querySelector(
        ".chat-message-info__bookmark .d-icon-discourse-bookmark-clock"
      ),
      "the message should be bookmarked and show the icon on the message info"
    );
    assert.ok(
      ".chat-message-actions .bookmark-btn .d-icon-discourse-bookmark-clock",
      "the message actions icon shows the reminder icon"
    );
  });

  test("can bookmark a message without reminder from the quick actions menu", async function (assert) {
    await visit("/chat/channel/4/public-category");
    assert.ok(exists(".chat-message-container"));
    const message = query(".chat-message-container");

    await triggerEvent(message, "mouseenter");
    await click(".chat-message-actions .bookmark-btn");
    assert.ok(
      exists("#bookmark-reminder-modal"),
      "it shows the bookmark modal"
    );
    await fillIn("input#bookmark-name", "Check this out later");
    await click("#tap_tile_none");
    assert.ok(
      exists(".chat-message-info__bookmark .d-icon-bookmark"),
      "the message should be bookmarked and show the icon on the message info"
    );
    assert.ok(
      exists(".chat-message-actions .bookmark-btn .d-icon-bookmark"),
      "the message actions icon shows the bookmark icon"
    );
  });
});

acceptance("Discourse Chat | bookmarking | mobile", function (needs) {
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
    server.post("/bookmarks", () => helper.response({ id: 1, success: "OK" }));
  });

  needs.mobileView();

  test("can bookmark a message with reminder from the mobile long press menu", async function (assert) {
    await visit("/chat/channel/4/public-category");
    assert.ok(exists(".chat-message-container"));
    const message = query(".chat-message-container");

    await tap(message);
    await click(".main-actions .bookmark-btn");

    assert.ok(
      exists("#bookmark-reminder-modal"),
      "it shows the bookmark modal"
    );
    await fillIn("input#bookmark-name", "Check this out later");
    await click("#tap_tile_next_month");
    assert.ok(
      message.querySelector(
        ".chat-message-info__bookmark .d-icon-discourse-bookmark-clock"
      ),
      "the message should be bookmarked and show the icon on the message info"
    );

    await tap(message);
    assert.ok(
      exists(".main-actions .bookmark-btn .d-icon-discourse-bookmark-clock"),
      "the message actions icon shows the reminder icon"
    );
  });

  test("can bookmark a message without reminder from the quick actions menu", async function (assert) {
    await visit("/chat/channel/4/public-category");
    assert.ok(exists(".chat-message-container"));
    const message = query(".chat-message-container");

    await tap(message);
    await click(".main-actions .bookmark-btn");
    assert.ok(
      exists("#bookmark-reminder-modal"),
      "it shows the bookmark modal"
    );
    await fillIn("input#bookmark-name", "Check this out later");
    await click("#tap_tile_none");
    assert.ok(
      message.querySelector(".chat-message-info__bookmark .d-icon-bookmark"),
      "the message should be bookmarked and show the icon on the message info"
    );

    await tap(message);
    assert.ok(
      exists(".main-actions .bookmark-btn .d-icon-bookmark"),
      "the message actions icon shows the bookmark icon"
    );
  });
});

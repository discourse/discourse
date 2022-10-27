import showModal from "discourse/lib/show-modal";
import {
  acceptance,
  exists,
  loggedInUser,
  query,
  queryAll,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import {
  click,
  currentURL,
  fillIn,
  focus,
  settled,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import {
  chatChannels,
  generateChatView,
} from "discourse/plugins/chat/chat-fixtures";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { KEY_MODIFIER } from "discourse/plugins/chat/discourse/initializers/chat-keyboard-shortcuts";
import { test } from "qunit";

const MODIFIER_OPTIONS =
  KEY_MODIFIER === "meta" ? { metaKey: true } : { ctrlKey: true };

acceptance("Discourse Chat - Keyboard shortcuts", function (needs) {
  needs.user({
    admin: false,
    moderator: false,
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });

  needs.pretender((server, helper) => {
    // allows to create a staged message
    server.post("/chat/:id.json", () =>
      helper.response({
        errors: [""],
      })
    );
    server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
    server.get("/chat/:chatChannelId/messages.json", () =>
      helper.response(generateChatView(loggedInUser()))
    );
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
    server.post("/chat/drafts", () => {
      return helper.response([]);
    });

    server.get("/chat/chat_channels/search", () => {
      return helper.response({
        public_channels: [ChatChannel.create({ id: 3, title: "seventeen" })],
        direct_message_channels: [
          ChatChannel.create({
            id: 4,
            users: [{ id: 10, username: "someone" }],
          }),
        ],
        users: [
          { id: 11, username: "smoothies" },
          { id: 12, username: "server" },
        ],
      });
    });
  });

  needs.settings({
    chat_enabled: true,
  });

  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatService", {
      get: () => this.container.lookup("service:chat"),
    });
  });

  test("channel selector opens channel in float", async function (assert) {
    await visit("/latest");

    await showModal("chat-channel-selector-modal");
    await settled();
    assert.ok(exists("#chat-channel-selector-modal-inner"));

    // All channels should show because the input is blank
    assert.equal(
      queryAll("#chat-channel-selector-modal-inner .chat-channel-selection-row")
        .length,
      9
    );

    // Freaking keyup event isn't triggered by fillIn...
    // Next line manually keyup's "r" to make the keyup event run.
    // fillIn is needed for `this.filter` but triggerKeyEvent is needed to fire the JS event.
    await fillIn("#chat-channel-selector-input", "s");
    await triggerKeyEvent("#chat-channel-selector-input", "keyup", "R");

    // Only 4 channels match this filter now!
    assert.equal(
      queryAll("#chat-channel-selector-modal-inner .chat-channel-selection-row")
        .length,
      4
    );

    await triggerKeyEvent(document.body, "keyup", "Enter");
    assert.ok(exists(".topic-chat-container.visible"));
    assert.notOk(exists("#chat-channel-selector-modal-inner"));
    assert.equal(currentURL(), "/latest");
  });

  test("the current chat channel does not show in the channel selector list", async function (assert) {
    await visit("/chat/channel/75/@hawk");
    await showModal("chat-channel-selector-modal");
    await settled();

    // All channels minus 1
    assert.equal(
      queryAll("#chat-channel-selector-modal-inner .chat-channel-selection-row")
        .length,
      8
    );
    assert.notOk(
      exists(
        "#chat-channel-selector-modal-inner .chat-channel-selection-row.chat-channel-9"
      )
    );
  });

  test("switching channel with alt+arrow keys in full page chat", async function (assert) {
    this.container.lookup("service:chat").set("chatWindowFullPage", true);
    await visit("/chat/channel/75/@hawk");
    await triggerKeyEvent(document.body, "keydown", "ArrowDown", {
      altKey: true,
    });
    assert.equal(currentURL(), "/chat/channel/76/eviltrout-markvanlan");
    await triggerKeyEvent(document.body, "keydown", "ArrowDown", {
      altKey: true,
    });
    assert.equal(currentURL(), "/chat/channel/11/another-category");
    await triggerKeyEvent(document.body, "keydown", "ArrowDown", {
      altKey: true,
    });
    assert.equal(currentURL(), "/chat/channel/7/bug");
    await triggerKeyEvent(document.body, "keydown", "ArrowUp", {
      altKey: true,
    });
    assert.equal(currentURL(), "/chat/channel/11/another-category");
    await triggerKeyEvent(document.body, "keydown", "ArrowUp", {
      altKey: true,
    });
    assert.equal(currentURL(), "/chat/channel/76/eviltrout-markvanlan");
    await triggerKeyEvent(document.body, "keydown", "ArrowUp", {
      altKey: true,
    });
    assert.equal(currentURL(), "/chat/channel/75/hawk");
  });

  test("switching channel with alt+arrow keys in float", async function (assert) {
    await visit("/latest");
    this.chatService.set("sidebarActive", false);
    this.chatService.set("chatWindowFullPage", false);

    await click(".header-dropdown-toggle.open-chat");
    assert.ok(visible(".topic-chat-float-container"), "chat float is open");
    assert.ok(query(".topic-chat-container").classList.contains("channel-4"));

    await triggerKeyEvent(document.body, "keydown", "ArrowDown", {
      altKey: true,
    });

    assert.ok(query(".topic-chat-container").classList.contains("channel-10"));

    await triggerKeyEvent(document.body, "keydown", "ArrowUp", {
      altKey: true,
    });
    assert.ok(query(".topic-chat-container").classList.contains("channel-4"));
  });

  test("simple composer formatting shortcuts", async function (assert) {
    await visit("/latest");
    this.chatService.set("sidebarActive", false);
    await click(".header-dropdown-toggle.open-chat");

    const composerInput = query(".chat-composer-input");
    await fillIn(composerInput, "test text");
    await focus(composerInput);
    composerInput.selectionStart = 0;
    composerInput.selectionEnd = 9;
    await triggerKeyEvent(composerInput, "keydown", "B", MODIFIER_OPTIONS);

    assert.strictEqual(
      composerInput.value,
      "**test text**",
      "selection should get the bold markdown"
    );
    await fillIn(composerInput, "test text");
    await focus(composerInput);
    composerInput.selectionStart = 0;
    composerInput.selectionEnd = 9;
    await triggerKeyEvent(composerInput, "keydown", "I", MODIFIER_OPTIONS);

    assert.strictEqual(
      composerInput.value,
      "_test text_",
      "selection should get the italic markdown"
    );
    await fillIn(composerInput, "test text");
    await focus(composerInput);
    composerInput.selectionStart = 0;
    composerInput.selectionEnd = 9;
    await triggerKeyEvent(composerInput, "keydown", "E", MODIFIER_OPTIONS);

    assert.strictEqual(
      composerInput.value,
      "`test text`",
      "selection should get the code markdown"
    );
  });

  test("editing last non staged message", async function (assert) {
    const stagedMessageText = "This is a test";
    await visit("/latest");

    this.chatService.set("sidebarActive", false);
    await click(".header-dropdown-toggle.open-chat");
    await fillIn(".chat-composer-input", stagedMessageText);
    await click(".chat-composer-inline-button");
    await triggerKeyEvent(".chat-composer-input", "keydown", "ArrowUp");

    assert.notEqual(
      query(".chat-composer-input").value.trim(),
      stagedMessageText
    );
  });

  test("insert link shortcut", async function (assert) {
    await visit("/latest");

    this.chatService.set("sidebarActive", false);
    await click(".header-dropdown-toggle.open-chat");

    await focus(".chat-composer-input");
    await fillIn(".chat-composer-input", "This is a link to ");
    await triggerKeyEvent(
      ".chat-composer-input",
      "keydown",
      "L",
      MODIFIER_OPTIONS
    );
    assert.ok(exists(".insert-link.modal-body"), "hyperlink modal visible");

    await fillIn(".modal-body .link-url", "google.com");
    await fillIn(".modal-body .link-text", "Google");
    await click(".modal-footer button.btn-primary");

    assert.strictEqual(
      query(".chat-composer-input").value,
      "This is a link to [Google](https://google.com)",
      "adds link with url and text, prepends 'https://'"
    );

    assert.ok(
      !exists(".insert-link.modal-body"),
      "modal dismissed after submitting link"
    );
  });

  test("Dash key (-) opens chat float", async function (assert) {
    await visit("/latest");
    this.chatService.set("sidebarActive", false);
    this.chatService.set("chatWindowFullPage", false);

    await triggerKeyEvent(document.body, "keydown", "-");
    assert.ok(exists(".topic-chat-drawer-content"), "chat float is open");
  });

  test("Pressing Escape when drawer is opened", async function (assert) {
    await visit("/latest");
    this.chatService.set("sidebarActive", false);
    this.chatService.set("chatWindowFullPage", false);
    await click(".header-dropdown-toggle.open-chat");

    const composerInput = query(".chat-composer-input");
    await focus(composerInput);
    await triggerKeyEvent(composerInput, "keydown", "Escape");

    assert.ok(
      exists(".topic-chat-float-container.hidden"),
      "it closes the drawer"
    );
  });

  test("Pressing Escape when full page is opened", async function (assert) {
    this.chatService.set("sidebarActive", false);
    this.chatService.set("chatWindowFullPage", true);
    await visit("/chat/channel/75/@hawk");
    const composerInput = query(".chat-composer-input");
    await focus(composerInput);
    await triggerKeyEvent(composerInput, "keydown", "Escape");

    assert.equal(
      currentURL(),
      "/chat/channel/75/hawk",
      "it doesn’t close full page chat"
    );

    assert.ok(
      exists(".chat-message-container[data-id='177']"),
      "it doesn’t remove channel content"
    );
  });
});

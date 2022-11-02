import { withPluginApi } from "discourse/lib/plugin-api";
import {
  acceptance,
  exists,
  loggedInUser,
  publishToMessageBus,
  query,
  queryAll,
  updateCurrentUser,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import {
  click,
  currentURL,
  fillIn,
  focus,
  settled,
  triggerEvent,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { skip, test } from "qunit";
import {
  chatChannels,
  messageContents,
} from "discourse/plugins/chat/chat-fixtures";
import Session from "discourse/models/session";
import { cloneJSON } from "discourse-common/lib/object";
import {
  joinChannel,
  leaveChannel,
  presentUserIds,
} from "discourse/tests/helpers/presence-pretender";
import User from "discourse/models/user";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import sinon from "sinon";
import * as ajaxModule from "discourse/lib/ajax";
import I18n from "I18n";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";
import fabricators from "../helpers/fabricators";
import {
  baseChatPretenders,
  chatChannelPretender,
  directMessageChannelPretender,
} from "../helpers/chat-pretenders";

acceptance("Discourse Chat - anonymouse 🐭 user", function (needs) {
  needs.settings({
    chat_enabled: true,
  });

  test("doesn't error for anonymous users", async function (assert) {
    await visit("");
    assert.ok(true, "no errors on homepage");
  });
});

acceptance("Discourse Chat - without unread", function (needs) {
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
    baseChatPretenders(server, helper);
    directMessageChannelPretender(server, helper);
    chatChannelPretender(server, helper);
    const hawkAsJson = {
      username: "hawk",
      id: 2,
      name: "hawk",
      avatar_template: "/letter_avatar_proxy/v4/letter/t/41988e/{size}.png",
    };
    server.get("/u/search/users", () => {
      return helper.response({
        users: [hawkAsJson],
      });
    });
    server.get("/chat/emojis.json", () =>
      helper.response({ favorites: [{ name: "grinning" }] })
    );

    server.put("/chat/:chat_channel_id/react/:messageId.json", helper.response);

    server.put("/chat/:chat_channel_id/invite", helper.response);
    server.post("/chat/direct_messages/create.json", () => {
      return helper.response({
        chat_channel: {
          chat_channels: [],
          chatable: { users: [hawkAsJson] },
          chatable_id: 16,
          chatable_type: "DirectMessageChannel",
          chatable_url: null,
          id: 75,
          title: "@hawk",
          last_message_sent_at: "2021-11-08T21:26:05.710Z",
          current_user_membership: {
            last_read_message_id: null,
            unread_count: 0,
            unread_mentions: 0,
          },
        },
      });
    });
    server.post("/chat/chat_channels/:chatChannelId/unfollow.json", () => {
      return helper.response({ current_user_membership: { following: false } });
    });
    server.get("/chat/direct_messages.json", () => {
      return helper.response({
        chat_channel: {
          id: 75,
          title: "hawk",
          chatable_type: "DirectMessageChannel",
          last_message_sent_at: "2021-07-20T08:14:16.950Z",
          chatable: {
            users: [{ username: "hawk" }],
          },
        },
      });
    });
    server.get("/u/hawk/card.json", () => {
      return helper.response({});
    });
  });
  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatService", {
      get: () => this.container.lookup("service:chat"),
    });
    Object.defineProperty(this, "appEvents", {
      get: () => this.container.lookup("service:appEvents"),
    });
    Session.current().highlightJsPath =
      "/assets/highlightjs/highlight-test-bundle.min.js";
  });

  // TODO: needs a future change to how we handle URLS to be possible
  skip("Clicking mention notification from outside chat opens the float", async function (assert) {
    this.chatService.set("chatWindowFullPage", false);
    await visit("/t/internationalization-localization/280");
    await click(".header-dropdown-toggle.current-user");
    await click("#quick-access-notifications .chat-mention");
    assert.ok(visible(".topic-chat-float-container"), "chat float is open");
    assert.ok(query(".topic-chat-container").classList.contains("channel-9"));
  });

  test("notifications for current user and here/all are highlighted", async function (assert) {
    updateCurrentUser({ username: "osama" });
    await visit("/chat/channel/11/another-category");
    // 177 is message id from fixture
    const highlighted = [];
    const notHighlighted = [];
    query(".chat-message-container[data-id='177']")
      .querySelectorAll(".mention.highlighted")
      .forEach((node) => {
        highlighted.push(node.textContent.trim());
      });
    query(".chat-message-container[data-id='177']")
      .querySelectorAll(".mention:not(.highlighted)")
      .forEach((node) => {
        notHighlighted.push(node.textContent.trim());
      });
    assert.equal(highlighted.length, 2, "2 mentions are highlighted");
    assert.equal(notHighlighted.length, 1, "1 mention is regular mention");
    assert.ok(highlighted.includes("@here"), "@here mention is highlighted");
    assert.ok(highlighted.includes("@osama"), "@osama mention is highlighted");
    assert.ok(
      notHighlighted.includes("@mark"),
      "@mark mention is not highlighted"
    );
  });

  test("Chat messages are populated when a channel is entered and images are rendered", async function (assert) {
    await visit("/chat/channel/11/another-category");
    const messages = queryAll(".chat-message .chat-message-text");
    assert.equal(messages[0].innerText.trim(), messageContents[0]);

    assert.ok(messages[1].querySelector("a.chat-other-upload"));

    assert.equal(
      messages[2].innerText.trim().split("\n")[0],
      messageContents[2]
    );
    assert.ok(messages[2].querySelector("img.chat-img-upload"));
  });

  test("Reply-to line is hidden when reply-to message is directly above", async function (assert) {
    await visit("/chat/channel/11/another-category");
    const messages = queryAll(".chat-message-container");
    assert.notOk(messages[1].querySelector(".chat-reply__excerpt"));
  });

  test("Reply-to line is present when reply-to message is not directly above", async function (assert) {
    await visit("/chat/channel/11/another-category");
    const messages = queryAll(".chat-message-container");
    const replyTo = messages[2].querySelector(".chat-reply__excerpt");
    assert.ok(replyTo);
    assert.equal(replyTo.innerText.trim(), messageContents[0]);
  });

  test("Unfollowing a direct message channel transitions to another channel", async function (assert) {
    await visit("/chat/channel/75/@hawk");
    await click(
      ".chat-channel-row.chat-channel-75 .toggle-channel-membership-button.-leave"
    );

    assert.ok(/^\/chat\/channel\/4/.test(currentURL()));
  });

  test("Admin only controls are present", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await triggerEvent(".chat-message-container[data-id='174']", "mouseenter");

    const currentUserDropdown = selectKit(
      ".chat-msgactions-hover[data-id='174'] .more-buttons"
    );
    await currentUserDropdown.expand();

    assert.notOk(
      currentUserDropdown.rowByValue("rebakeMessage").exists(),
      "it doesn’t show the rebake button for non staff"
    );

    await visit("/");
    updateCurrentUser({ admin: true, moderator: true });
    await visit("/chat/channel/11/another-category");
    await triggerEvent(".chat-message-container[data-id='174']", "mouseenter");
    await currentUserDropdown.expand();

    assert.ok(
      currentUserDropdown.rowByValue("rebakeMessage").exists(),
      "it shows the rebake button"
    );

    assert.notOk(
      currentUserDropdown.rowByValue("silence").exists(),
      "it hides the silence button"
    );

    const notCurrentUserDropdown = selectKit(
      ".chat-msgactions-hover[data-id='175'] .more-buttons"
    );
    await triggerEvent(".chat-message-container[data-id='175']", "mouseenter");
    await notCurrentUserDropdown.expand();
    assert.ok(
      notCurrentUserDropdown.rowByValue("silence").exists(),
      "it shows the silence button"
    );
  });

  test("Message controls are present and correct for permissions", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await triggerEvent(".chat-message-container[data-id='174']", "mouseenter");

    // User created this message
    assert.ok(
      ".chat-msgactions-hover[data-id='174'] .reply-btn",
      "it shows the reply button"
    );

    const currentUserDropdown = selectKit(
      ".chat-msgactions-hover[data-id='174'] .more-buttons"
    );
    await currentUserDropdown.expand();

    assert.ok(
      currentUserDropdown.rowByValue("copyLinkToMessage").exists(),
      "it shows the link to button"
    );

    assert.notOk(
      currentUserDropdown.rowByValue("rebakeMessage").exists(),
      "it doesn’t show the rebake button to a regular user"
    );

    assert.ok(
      currentUserDropdown.rowByValue("edit").exists(),
      "it shows the edit button"
    );

    assert.notOk(
      currentUserDropdown.rowByValue("flag").exists(),
      "it hides the flag button"
    );

    assert.notOk(
      currentUserDropdown.rowByValue("silence").exists(),
      "it hides the silence button"
    );

    assert.ok(
      currentUserDropdown.rowByValue("deleteMessage").exists(),
      "it shows the delete button"
    );

    // User _didn't_ create this message
    await triggerEvent(".chat-message-container[data-id='175']", "mouseenter");
    assert.ok(
      ".chat-msgactions-hover[data-id='175'] .reply-btn",
      "it shows the reply button"
    );
    const notCurrentUserDropdown = selectKit(
      ".chat-msgactions-hover[data-id='175'] .more-buttons"
    );
    await notCurrentUserDropdown.expand();

    assert.ok(
      notCurrentUserDropdown.rowByValue("copyLinkToMessage").exists(),
      "it shows the link to button"
    );

    assert.notOk(
      notCurrentUserDropdown.rowByValue("edit").exists(),
      "it hides the edit button"
    );

    assert.notOk(
      notCurrentUserDropdown.rowByValue("deleteMessage").exists(),
      "it hides the delete button"
    );
  });

  test("pressing the reply button adds the indicator to the composer", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await triggerEvent(".chat-message-container[data-id='174']", "mouseenter");
    await click(".reply-btn");
    assert.ok(
      exists(".chat-composer-message-details .d-icon-reply"),
      "Reply icon is present"
    );
    assert.equal(
      query(
        ".chat-composer-message-details .chat-reply__username"
      ).innerText.trim(),
      "markvanlan"
    );
  });

  test("pressing the edit button fills the composer and indicates edit", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await triggerEvent(".chat-message-container[data-id='174']", "mouseenter");

    const dropdown = selectKit(".more-buttons");
    await dropdown.expand();
    await dropdown.selectRowByValue("edit");

    assert.ok(
      exists(".chat-composer-message-details .d-icon-pencil-alt"),
      "Edit icon is present"
    );
    assert.equal(
      query(
        ".chat-composer-message-details .chat-reply__username"
      ).innerText.trim(),
      "markvanlan"
    );

    assert.equal(
      query(".chat-composer-input").value.trim(),
      messageContents[0]
    );
  });

  test("Reply-to is stored in draft", async function (assert) {
    this.chatService.set("sidebarActive", false);
    this.chatService.set("chatWindowFullPage", false);
    await visit("/latest");
    this.appEvents.trigger("chat:toggle-open");
    await settled();

    await click(".topic-chat-drawer-header__return-to-channels-btn");
    await click(".chat-channel-row.chat-channel-9");
    await triggerEvent(".chat-message-container[data-id='174']", "mouseenter");
    await click(".chat-msgactions-hover[data-id='174'] .reply-btn");
    // Reply-to line is present
    assert.ok(exists(".chat-composer-message-details .chat-reply"));
    await click(".topic-chat-drawer-header__return-to-channels-btn");
    await click(".chat-channel-row.chat-channel-11");
    // Reply-to line is gone since switching channels
    assert.notOk(exists(".chat-composer-message-details .chat-reply"));
    // Now click on reply btn and cancel it on channel 7

    await triggerEvent(".chat-message-container[data-id='174']", "mouseenter");
    await click(".chat-msgactions-hover[data-id='174'] .reply-btn");
    await click(".cancel-message-action");

    // Go back to channel 9 and check that reply-to is present
    await click(".topic-chat-drawer-header__return-to-channels-btn");
    await click(".chat-channel-row.chat-channel-9");
    // Now reply-to should be back and loaded from draft
    assert.ok(exists(".chat-composer-message-details .chat-reply"));

    // Go back one for time to channel 7 and make sure reply-to is gone
    await click(".topic-chat-drawer-header__return-to-channels-btn");
    await click(".chat-channel-row.chat-channel-11");
    assert.notOk(exists(".chat-composer-message-details .chat-reply"));
  });

  test("Sending a message", async function (assert) {
    await visit("/chat/channel/11/another-category");
    const messageContent = "Here's a message";
    const composerInput = query(".chat-composer-input");
    assert.deepEqual(
      presentUserIds("/chat-reply/11"),
      [],
      "is not present before typing"
    );
    await fillIn(composerInput, messageContent);
    assert.deepEqual(
      presentUserIds("/chat-reply/11"),
      [User.current().id],
      "is present after typing"
    );
    await focus(composerInput);

    await triggerKeyEvent(composerInput, "keydown", "Enter");

    assert.equal(document.activeElement, composerInput);

    assert.equal(composerInput.innerText.trim(), "", "composer input cleared");

    assert.deepEqual(
      presentUserIds("/chat-reply/11"),
      [],
      "stops being present after sending message"
    );

    let messages = queryAll(".chat-message");
    let lastMessage = messages[messages.length - 1];

    // Message is staged, without an ID
    assert.ok(lastMessage.classList.contains("chat-message-staged"));

    // Last message was from a different user; full meta data is shown
    assert.ok(
      lastMessage.querySelector(".chat-user-avatar"),
      "Avatar is present"
    );
    assert.ok(
      lastMessage.querySelector(".chat-message-info__username__name"),
      "Username is present"
    );
    assert.equal(
      lastMessage.querySelector(".chat-message-text").innerText.trim(),
      this.siteSettings.enable_markdown_typographer
        ? "Here’s a message"
        : messageContent
    );

    await publishToMessageBus("/chat/11", {
      type: "sent",
      stagedId: 1,
      chat_message: {
        id: 202,
        user: {
          id: 1,
        },
        cooked: messageContent + " some extra cooked stuff",
      },
    });

    assert.equal(
      lastMessage.closest(".chat-message-container").dataset.id,
      202
    );
    assert.notOk(lastMessage.classList.contains("chat-message-staged"));

    assert.equal(
      lastMessage.querySelector(".chat-message-text").innerText.trim(),
      messageContent + " some extra cooked stuff",
      "last message is updated with the cooked content of the message"
    );

    const nextMessageContent = "What up what up!";
    await fillIn(composerInput, nextMessageContent);
    await focus(composerInput);
    await triggerKeyEvent(composerInput, "keydown", "Enter");

    messages = queryAll(".chat-message");
    lastMessage = messages[messages.length - 1];

    // We just sent a message so avatar/username will not be present for the last message
    assert.notOk(
      lastMessage.querySelector(".chat-user-avatar"),
      "Avatar is not shown"
    );
    assert.notOk(
      lastMessage.querySelector(".full-name"),
      "Username is not shown"
    );
    assert.equal(
      lastMessage.querySelector(".chat-message-text").innerText.trim(),
      nextMessageContent
    );
  });

  test("cooked processing messages are handled properly", async function (assert) {
    await visit("/chat/channel/11/another-category");

    const cooked = "<h1>hello there</h1>";
    await publishToMessageBus(`/chat/11`, {
      type: "processed",
      chat_message: {
        cooked,
        id: 175,
      },
    });

    assert.ok(
      query(
        ".chat-message-container[data-id='175'] .chat-message-text"
      ).innerHTML.includes(cooked)
    );
  });

  test("Code highlighting in a message", async function (assert) {
    await visit("/chat/channel/11/another-category");
    const messageContent = `Here's a message with code highlighting

\`\`\`ruby
Widget.triangulate(arg: "test")
\`\`\``;
    const composerInput = query(".chat-composer-input");
    await fillIn(composerInput, messageContent);
    await focus(composerInput);
    await triggerKeyEvent(composerInput, "keydown", "Enter");

    await publishToMessageBus("/chat/11", {
      type: "sent",
      stagedId: 1,
      chat_message: {
        id: 202,
        cooked: `<pre><code class="lang-ruby">Widget.triangulate(arg: "test")
      </code></pre>`,
        user: {
          id: 1,
        },
      },
    });

    const messages = queryAll(".chat-message");
    const lastMessage = messages[messages.length - 1];
    assert.equal(
      lastMessage.closest(".chat-message-container").dataset.id,
      202
    );
    assert.ok(
      exists(
        ".chat-message-container[data-id='202'] .chat-message-text code.lang-ruby.hljs"
      ),
      "chat message code block has been highlighted as ruby code"
    );
  });

  test("Drafts are saved and reloaded", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await fillIn(".chat-composer-input", "Hi people");

    await visit("/chat/channel/75/@hawk");
    assert.equal(query(".chat-composer-input").value.trim(), "");
    await fillIn(".chat-composer-input", "What up what up");

    await visit("/chat/channel/11/another-category");
    assert.equal(query(".chat-composer-input").value.trim(), "Hi people");
    await fillIn(".chat-composer-input", "");

    await visit("/chat/channel/75/@hawk");
    assert.equal(query(".chat-composer-input").value.trim(), "What up what up");

    // Send a message
    const composerTextarea = query(".chat-composer-input");
    await focus(composerTextarea);
    await triggerKeyEvent(composerTextarea, "keydown", "Enter");

    assert.equal(query(".chat-composer-input").value.trim(), "");

    // Navigate away and back to make sure input didn't re-fill
    await visit("/chat/channel/11/another-category");
    await visit("/chat/channel/75/@hawk");
    assert.equal(query(".chat-composer-input").value.trim(), "");
  });

  test("Pressing escape cancels editing", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await triggerEvent(".chat-message-container[data-id='174']", "mouseenter");

    const dropdown = selectKit(".more-buttons");
    await dropdown.expand();
    await dropdown.selectRowByValue("edit");

    assert.ok(exists(".chat-composer-message-details"));
    await triggerKeyEvent(".chat-composer", "keydown", "Escape");

    // chat-composer-message-details will be gone as no message is being edited
    assert.notOk(exists(".chat-composer .chat-composer-message-details"));
  });

  test("Unread indicator increments for public channels when messages come in", async function (assert) {
    await visit("/t/internationalization-localization/280");
    assert.notOk(
      exists(".header-dropdown-toggle.open-chat .chat-channel-unread-indicator")
    );

    await publishToMessageBus("/chat/9/new-messages", {
      message_id: 201,
      user_id: 2,
    });

    assert.ok(
      exists(".header-dropdown-toggle.open-chat .chat-channel-unread-indicator")
    );
  });

  test("Unread count increments for direct message channels when messages come in", async function (assert) {
    await visit("/t/internationalization-localization/280");
    assert.notOk(
      exists(
        ".header-dropdown-toggle.open-chat .chat-channel-unread-indicator.urgent .number"
      )
    );

    await publishToMessageBus("/chat/75/new-messages", {
      message_id: 201,
      user_id: 2,
    });
    assert.ok(
      exists(
        ".header-dropdown-toggle.open-chat .chat-channel-unread-indicator.urgent .number"
      )
    );
    assert.equal(
      query(
        ".header-dropdown-toggle.open-chat .chat-channel-unread-indicator.urgent .number"
      ).innerText.trim(),
      1
    );
  });

  test("Unread DM count overrides the public unread indicator", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await publishToMessageBus("/chat/9/new-messages", {
      message_id: 201,
      user_id: 2,
    });
    await publishToMessageBus("/chat/75/new-messages", {
      message_id: 202,
      user_id: 2,
    });
    assert.ok(
      exists(
        ".header-dropdown-toggle.open-chat .chat-channel-unread-indicator.urgent .number"
      )
    );
    assert.notOk(
      exists(
        ".header-dropdown-toggle.open-chat .chat-channel-unread-indicator:not(.urgent)"
      )
    );
  });

  test("Mentions in public channels show the unread urgent indicator", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await publishToMessageBus("/chat/9/new-mentions", {
      message_id: 201,
    });
    assert.ok(
      exists(
        ".header-dropdown-toggle.open-chat .chat-channel-unread-indicator.urgent .number"
      )
    );
    assert.notOk(
      exists(
        ".header-dropdown-toggle.open-chat .chat-channel-unread-indicator:not(.urgent)"
      )
    );
  });

  test("message selection and live pane buttons for regular user", async function (assert) {
    updateCurrentUser({ admin: false, moderator: false });
    await visit("/chat/channel/11/another-category");

    const firstMessage = query(".chat-message-container");
    await triggerEvent(firstMessage, "mouseenter");
    const dropdown = selectKit(
      `.chat-msgactions-hover[data-id="${firstMessage.dataset.id}"] .more-buttons`
    );
    await dropdown.expand();
    await dropdown.selectRowByValue("selectMessage");

    assert.ok(firstMessage.classList.contains("selecting-messages"));
    assert.ok(exists("#chat-quote-btn"));
  });

  test("message selection is not present for regular user", async function (assert) {
    updateCurrentUser({ admin: false, moderator: false });
    await visit("/chat/channel/11/another-category");
    assert.notOk(
      exists(".chat-message-container .chat-msgactions-hover .select-btn")
    );
  });

  test("creating a new direct message channel works", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await click(".new-dm");
    await fillIn(".filter-usernames", "hawk");
    await click("li.user[data-username='hawk']");

    assert.notOk(
      query(".join-channel-btn"),
      "Join channel button is not present"
    );
    const enabledComposer = document.querySelector(".chat-composer-input");
    assert.ok(!enabledComposer.disabled);
    assert.equal(
      enabledComposer.placeholder,
      I18n.t("chat.placeholder_start_conversation", { usernames: "hawk" })
    );
  });

  test("creating a new direct message channel from popup chat works", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".new-dm");
    await fillIn(".filter-usernames", "hawk");
    await click('.chat-user-avatar-container[data-user-card="hawk"]');
    assert.ok(query(".selected-user").innerText, "hawk");
  });

  test("Reacting works with no existing reactions", async function (assert) {
    await visit("/chat/channel/11/another-category");
    const message = query(".chat-message-container");
    await triggerEvent(message, "mouseenter");
    assert.notOk(message.querySelector(".chat-message-reaction-list"));
    await click(".chat-msgactions .react-btn");
    await click(`.chat-emoji-picker .emoji[alt="grinning"]`);

    assert.ok(message.querySelector(".chat-message-reaction-list"));
    const reaction = message.querySelector(
      ".chat-message-reaction-list .chat-message-reaction.reacted"
    );
    assert.ok(reaction);
    assert.equal(reaction.querySelector(".count").innerText.trim(), 1);
  });

  test("Reacting works with existing reactions", async function (assert) {
    await visit("/chat/channel/11/another-category");
    const messages = queryAll(".chat-message-container");

    // First 2 messages have no reactions; make sure the list isn't rendered
    assert.notOk(messages[0].querySelector(".chat-message-reaction-list"));
    assert.notOk(messages[1].querySelector(".chat-message-reaction-list"));

    const lastMessage = messages[2];
    assert.ok(lastMessage.querySelector(".chat-message-reaction-list"));
    assert.equal(
      lastMessage.querySelectorAll(".chat-message-reaction.reacted").length,
      2
    );
    assert.equal(
      lastMessage.querySelectorAll(".chat-message-reaction:not(.reacted)")
        .length,
      1
    );

    // React with a heart and make sure the count increments and class is added
    const heartReaction = lastMessage.querySelector(
      `.chat-message-reaction[data-emoji-name="heart"]`
    );
    assert.equal(heartReaction.innerText.trim(), "1");
    await click(heartReaction);
    assert.equal(heartReaction.innerText.trim(), "2");
    assert.ok(heartReaction.classList.contains("reacted"));

    await publishToMessageBus("/chat/11", {
      action: "add",
      user: { id: 1, username: "eviltrout" },
      emoji: "heart",
      type: "reaction",
      chat_message_id: 176,
    });

    // Click again make sure count goes down
    await click(heartReaction);
    assert.equal(heartReaction.innerText.trim(), "1");
    assert.notOk(heartReaction.classList.contains("reacted"));

    // Message from another user coming in!
    await publishToMessageBus("/chat/11", {
      action: "add",
      user: { id: 77, username: "rando" },
      emoji: "sneezing_face",
      type: "reaction",
      chat_message_id: 176,
    });
    const sneezingFaceReaction = lastMessage.querySelector(
      `.chat-message-reaction[data-emoji-name="sneezing_face"]`
    );
    assert.ok(sneezingFaceReaction);
    assert.equal(sneezingFaceReaction.innerText.trim(), "1");
    assert.notOk(sneezingFaceReaction.classList.contains("reacted"));
    await click(sneezingFaceReaction);
    assert.equal(sneezingFaceReaction.innerText.trim(), "2");
    assert.ok(sneezingFaceReaction.classList.contains("reacted"));
  });

  test("Reacting and unreacting works on newly created chat messages", async function (assert) {
    await visit("/chat/channel/11/another-category");
    const composerInput = query(".chat-composer-input");
    await fillIn(composerInput, "hellloooo");
    await focus(composerInput);
    await triggerKeyEvent(composerInput, "keydown", "Enter");

    const messages = queryAll(".chat-message-container");
    const lastMessage = messages[messages.length - 1];
    await publishToMessageBus("/chat/11", {
      type: "sent",
      stagedId: 1,
      chat_message: {
        id: 202,
        user: {
          id: 1,
        },
        cooked: "<p>hellloooo</p>",
      },
    });

    assert.deepEqual(lastMessage.dataset.id, "202");
    await triggerEvent(lastMessage, "mouseenter");
    await click(
      `.chat-msgactions-hover[data-id="${lastMessage.dataset.id}"] .react-btn`
    );
    await click(`.emoji[alt="grinning"]`);

    const reaction = lastMessage.querySelector(
      `.chat-message-reaction.reacted[data-emoji-name="grinning"]`
    );

    await publishToMessageBus("/chat/11", {
      action: "add",
      user: { id: 1, username: "eviltrout" },
      emoji: "grinning",
      type: "reaction",
      chat_message_id: 202,
    });
    await click(reaction);

    assert.notOk(
      lastMessage.querySelector(
        `.chat-message-reaction.reacted[data-emoji-name="grinning"]`
      )
    );
  });

  test("mention warning is rendered", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await publishToMessageBus("/chat/11", {
      type: "mention_warning",
      cannot_see: [{ id: 75, username: "hawk" }],
      without_membership: [
        { id: 76, username: "eviltrout" },
        { id: 77, username: "sam" },
      ],
      chat_message_id: 176,
    });

    assert.ok(
      exists(
        ".chat-message-container[data-id='176'] .chat-message-mention-warning"
      )
    );

    assert.ok(
      query(
        ".chat-message-container[data-id='176'] .chat-message-mention-warning .cannot-see"
      ).innerText.includes("hawk")
    );

    const withoutMembershipText = query(
      ".chat-message-container[data-id='176'] .chat-message-mention-warning .without-membership"
    ).innerText;
    assert.ok(withoutMembershipText.includes("eviltrout"));
    assert.ok(withoutMembershipText.includes("sam"));

    await click(
      ".chat-message-container[data-id='176'] .chat-message-mention-warning .invite-link"
    );
    assert.notOk(
      exists(
        ".chat-message-container[data-id='176'] .chat-message-mention-warning"
      )
    );
  });

  test("It displays a separator between days", async function (assert) {
    await visit("/chat/channel/11/another-category");
    assert.equal(
      query(".first-daily-message").innerText.trim(),
      "July 22, 2021"
    );
  });

  test("pressing keys focuses composer in full page chat", async function (assert) {
    await visit("/chat/channel/11/another-category");

    document.activeElement.blur();
    await triggerKeyEvent(document.body, "keydown", 65); // 65 is `a` keycode
    let composer = query(".chat-composer-input");
    assert.equal(composer.value, "a");
    assert.equal(document.activeElement, composer);

    document.activeElement.blur();
    await triggerKeyEvent(document.body, "keydown", 65);
    assert.equal(composer.value, "aa");
    assert.equal(document.activeElement, composer);

    document.activeElement.blur();
    await triggerKeyEvent(document.body, "keydown", 191); // 191 is `?`
    assert.notEqual(
      document.activeElement,
      composer,
      "? is a special case and should not focus"
    );

    document.activeElement.blur();
    await triggerKeyEvent(document.body, "keydown", "Enter");
    assert.notEqual(
      document.activeElement,
      composer,
      "enter is a special case and should not focus"
    );
  });

  test("changing channel resets message selection", async function (assert) {
    await visit("/chat/channel/11/another-category");
    await triggerEvent(".chat-message-container", "mouseenter");
    const dropdown = selectKit(".chat-msgactions .more-buttons");
    await dropdown.expand();
    await dropdown.selectRowByValue("selectMessage");
    await click("#chat-copy-btn");
    await click("#chat-channel-row-9");

    assert.notOk(exists("#chat-copy-btn"));
  });
});

acceptance(
  "Discourse Chat - Acceptance Test with unread public channel messages",
  function (needs) {
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
      baseChatPretenders(server, helper);
      directMessageChannelPretender(server, helper);
      chatChannelPretender(server, helper, [
        { id: 11, unread_count: 2, muted: false },
      ]);
    });
    needs.hooks.beforeEach(function () {
      Object.defineProperty(this, "chatService", {
        get: () => this.container.lookup("service:chat"),
      });
    });

    test("Expand button takes you to full page chat on the correct channel", async function (assert) {
      await visit("/t/internationalization-localization/280");
      this.chatService.set("sidebarActive", false);
      await visit(".header-dropdown-toggle.open-chat");
      await click(".topic-chat-drawer-header__full-screen-btn");

      assert.equal(currentURL(), `/chat/channel/11/another-category`);
    });

    test("Chat opens to full-page channel with unread messages when sidebar is installed", async function (assert) {
      await visit("/t/internationalization-localization/280");
      this.chatService.set("sidebarActive", true);

      await click(".header-dropdown-toggle.open-chat");

      assert.equal(currentURL(), `/chat/channel/11/another-category`);
      assert.notOk(
        visible(".topic-chat-float-container"),
        "chat float is not open"
      );
    });

    test("Chat float opens on header icon click when sidebar is not installed", async function (assert) {
      await visit("/t/internationalization-localization/280");
      this.chatService.set("sidebarActive", false);
      this.chatService.set("chatWindowFullPage", false);
      await click(".header-dropdown-toggle.open-chat");
      assert.ok(visible(".topic-chat-float-container"), "chat float is open");
    });

    test("Unread header indicator is present", async function (assert) {
      await visit("/t/internationalization-localization/280");

      assert.ok(
        exists(
          ".header-dropdown-toggle.open-chat .chat-channel-unread-indicator"
        ),
        "Unread indicator present in header"
      );
    });
  }
);

acceptance(
  "Discourse Chat - Acceptance Test show/hide close fullscreen chat button",
  function (needs) {
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
      baseChatPretenders(server, helper);
      chatChannelPretender(server, helper, [
        { id: 9, unread_count: 2, muted: false },
      ]);
    });
    needs.hooks.beforeEach(function () {
      Object.defineProperty(this, "chatService", {
        get: () => this.container.lookup("service:chat"),
      });
    });

    test("Close fullscreen chat button present", async function (assert) {
      await visit("/chat/channel/11/another-category");
      assert.ok(exists(".chat-full-screen-button"));
    });
  }
);

acceptance(
  "Discourse Chat - Expand and collapse chat drawer (topic-chat-float)",
  function (needs) {
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
      baseChatPretenders(server, helper);
      chatChannelPretender(server, helper, [
        { id: 9, unread_count: 2, muted: false },
      ]);

      server.get("/chat/api/chat_channels/:id/memberships.json", () => {
        return helper.response([]);
      });
    });
    needs.hooks.beforeEach(function () {
      Object.defineProperty(this, "chatService", {
        get: () => this.container.lookup("service:chat"),
      });
    });

    test("chat drawer can be collapsed and expanded", async function (assert) {
      await visit("/t/internationalization-localization/280");
      this.chatService.set("sidebarActive", false);
      await click(".header-dropdown-toggle.open-chat");
      assert.ok(
        visible(".topic-chat-drawer-header__top-line--expanded"),
        "chat float is expanded"
      );
      await click(".topic-chat-drawer-header__expand-btn");
      assert.ok(
        visible(".topic-chat-drawer-header__top-line--collapsed"),
        "chat float is collapsed"
      );
      await click(".topic-chat-drawer-header__expand-btn");
      assert.ok(
        visible(".topic-chat-drawer-header__top-line--expanded"),
        "chat float is expanded"
      );
    });

    test("chat drawer title links to channel info when expanded", async function (assert) {
      await visit("/t/internationalization-localization/280");
      this.chatService.set("sidebarActive", false);
      await click(".header-dropdown-toggle.open-chat");
      assert.ok(
        visible(".topic-chat-drawer-header__top-line--expanded"),
        "chat float is expanded"
      );
      await click(".topic-chat-drawer-header__title");
      assert.equal(currentURL(), `/chat/channel/9/site/info/members`);
    });

    test("chat drawer title expands the chat drawer when collapsed", async function (assert) {
      await visit("/t/internationalization-localization/280");
      this.chatService.set("sidebarActive", false);
      await click(".header-dropdown-toggle.open-chat");
      assert.ok(
        visible(".topic-chat-drawer-header__top-line--expanded"),
        "chat float is expanded"
      );
      await click(".topic-chat-drawer-header__expand-btn");
      assert.ok(
        visible(".topic-chat-drawer-header__top-line--collapsed"),
        "chat float is collapsed"
      );
      await click(".topic-chat-drawer-header__title");
      assert.ok(
        visible(".topic-chat-drawer-header__top-line--expanded"),
        "chat float is expanded"
      );
    });
  }
);

acceptance(
  "Discourse Chat - Acceptance Test with unread DMs and public channel messages",
  function (needs) {
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
      baseChatPretenders(server, helper);
      directMessageChannelPretender(server, helper);
      // chat channel with ID 75 is direct message channel.
      chatChannelPretender(server, helper, [
        { id: 9, unread_count: 2, muted: false },
        { id: 75, unread_count: 2, muted: false },
      ]);
    });
    needs.hooks.beforeEach(function () {
      Object.defineProperty(this, "chatService", {
        get: () => this.container.lookup("service:chat"),
      });
    });

    test("Unread indicator doesn't show when user is in do not disturb", async function (assert) {
      let now = new Date();
      let later = new Date();
      later.setTime(now.getTime() + 600000);
      updateCurrentUser({ do_not_disturb_until: later.toUTCString() });
      await visit("/t/internationalization-localization/280");
      assert.notOk(
        exists(
          ".header-dropdown-toggle.open-chat .chat-unread-urgent-indicator"
        )
      );
    });

    test("Chat float open to DM channel with unread messages with sidebar off", async function (assert) {
      await visit("/t/internationalization-localization/280");
      this.chatService.set("sidebarActive", false);
      this.chatService.set("chatWindowFullPage", false);
      await click(".header-dropdown-toggle.open-chat");
      const chatContainer = query(".topic-chat-container");
      assert.ok(chatContainer.classList.contains("channel-75"));
    });

    test("Chat full page open to DM channel with unread messages with sidebar on", async function (assert) {
      this.chatService.set("sidebarActive", true);
      await visit("/t/internationalization-localization/280");
      await click(".header-dropdown-toggle.open-chat");

      assert.equal(currentURL(), `/chat/channel/75/hawk`);
    });
  }
);

acceptance(
  "Discourse Chat - chat channel settings and creation",
  function (needs) {
    needs.user({
      admin: true,
      moderator: true,
      username: "eviltrout",
      id: 1,
      can_chat: true,
      has_chat_enabled: true,
    });

    needs.settings({
      chat_enabled: true,
    });

    needs.pretender((server, helper) => {
      baseChatPretenders(server, helper);
      chatChannelPretender(server, helper);

      const channel = {
        chatable: {},
        chatable_id: 88,
        chatable_type: "Category",
        chatable_url: null,
        id: 88,
        title: "Something",
        last_message_sent_at: "2021-11-08T21:26:05.710Z",
        current_user_membership: {
          last_read_message_id: null,
          unread_count: 0,
          unread_mentions: 0,
        },
      };

      server.get("/chat/api/chat_channels.json", () => {
        return helper.response([fabricators.chatChannel()]);
      });

      server.get("/chat/chat_channels/:id.json", () => {
        return helper.response(channel);
      });

      server.put("/chat/chat_channels", () => {
        return helper.response({
          chat_channel: channel,
        });
      });
    });

    test("Create channel modal", async function (assert) {
      this.container.lookup("service:chat").set("chatWindowFullPage", true);

      await visit("/chat/browse");
      await click(".new-channel-btn");

      assert.strictEqual(currentURL(), "/chat/browse/open");

      let categories = selectKit(".create-channel-modal .category-chooser");
      await categories.expand();
      await categories.selectRowByValue("6"); // Category 6 is "support"
      assert.strictEqual(
        query(".create-channel-modal .create-channel-name-input").value.trim(),
        "support"
      );
      assert.notOk(query(".create-channel-modal .btn.create").disabled);

      await click(".create-channel-modal .btn.create");
      assert.strictEqual(currentURL(), "/chat/channel/88/something");
    });
  }
);

acceptance("Discourse Chat - chat preferences", function (needs) {
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
    baseChatPretenders(server, helper);
    directMessageChannelPretender(server, helper);
    chatChannelPretender(server, helper);
  });
  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatService", {
      get: () => this.container.lookup("service:chat"),
    });
  });

  test("Chat preferences route takes user to homepage when can_chat is false", async function (assert) {
    updateCurrentUser({ can_chat: false });
    await visit("/u/eviltrout/preferences/chat");
    assert.equal(currentURL(), "/latest");
  });

  test("There are all 5 settings shown", async function (assert) {
    this.chatService.set("sidebarActive", true);
    await visit("/u/eviltrout/preferences/chat");
    assert.equal(currentURL(), "/u/eviltrout/preferences/chat");
    assert.equal(queryAll(".chat-setting").length, 5);
  });

  test("The user can save the settings", async function (assert) {
    updateCurrentUser({ has_chat_enabled: false });
    const spy = sinon.spy(ajaxModule, "ajax");
    await visit("/u/eviltrout/preferences/chat");
    await click("#user_chat_enabled");
    await click("#user_chat_only_push_notifications");
    await click("#user_chat_ignore_channel_wide_mention");
    await selectKit("#user_chat_sounds").expand();
    await selectKit("#user_chat_sounds").selectRowByValue("bell");
    await selectKit("#user_chat_email_frequency").expand();
    await selectKit("#user_chat_email_frequency").selectRowByValue("never");

    await click(".save-changes");

    assert.ok(
      spy.calledWithMatch("/u/eviltrout.json", {
        data: {
          chat_enabled: true,
          chat_sound: "bell",
          only_chat_push_notifications: true,
          ignore_channel_wide_mention: true,
          chat_email_frequency: "never",
        },
        type: "PUT",
      }),
      "is able to save the chat preferences for the user"
    );
  });
});

acceptance("Discourse Chat - plugin API", function (needs) {
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
    baseChatPretenders(server, helper);
    directMessageChannelPretender(server, helper);
    chatChannelPretender(server, helper);
  });

  test("defines a decorateChatMessage plugin API", async function (assert) {
    withPluginApi("1.1.0", (api) => {
      api.decorateChatMessage((message) => {
        message.innerText = "test";
      });
    });

    await visit("/chat/channel/75/@hawk");

    assert.equal(
      document.querySelector('.chat-message-container[data-id="177"]')
        .innerText,
      "test"
    );
  });
});

acceptance("Discourse Chat - image uploads", function (needs) {
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
    chat_allow_uploads: true,
  });
  needs.pretender((server, helper) => {
    baseChatPretenders(server, helper);
    directMessageChannelPretender(server, helper);
    chatChannelPretender(server, helper);

    server.post(
      "/uploads.json",
      () => {
        return helper.response({
          extension: "jpeg",
          filesize: 126177,
          height: 800,
          human_filesize: "123 KB",
          id: 202,
          original_filename: "avatar.PNG.jpg",
          retain_hours: null,
          short_path: "/images/avatar.png",
          short_url: "upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
          thumbnail_height: 320,
          thumbnail_width: 690,
          url: "/images/avatar.png",
          width: 1920,
        });
      },
      500 // this delay is important to slow down the uploads a bit so we can click elements in the UI like the cancel button
    );
  });

  test("uploading files in chat works", async function (assert) {
    await visit("/t/internationalization-localization/280");
    this.container.lookup("service:chat").set("sidebarActive", false);
    this.container.lookup("service:chat").set("chatWindowFullPage", false);
    await click(".header-dropdown-toggle.open-chat");

    assert.ok(visible(".topic-chat-float-container"), "chat float is open");

    const appEvents = loggedInUser().appEvents;
    const done = assert.async();

    appEvents.on(
      "upload-mixin:chat-composer-uploader:all-uploads-complete",
      async () => {
        await settled();
        assert.ok(
          exists(".preview .preview-img"),
          "the chat upload preview should show"
        );
        assert.notOk(
          exists(".bottom-data .uploading"),
          "the chat upload preview should no longer say it is uploading"
        );
        assert.strictEqual(
          queryAll(".chat-composer-input").val(),
          "",
          "the chat composer does not get the upload markdown when the upload is complete"
        );
        done();
      }
    );

    appEvents.on(
      "upload-mixin:chat-composer-uploader:upload-started",
      async () => {
        await settled();
        assert.ok(
          exists(".chat-upload"),
          "the chat upload preview should show"
        );
        assert.ok(
          exists(".bottom-data .uploading"),
          "the chat upload preview should say it is uploading"
        );
        assert.strictEqual(
          queryAll(".chat-composer-input").val(),
          "",
          "the chat composer does not get an uploading... placeholder"
        );
      }
    );

    const image = createFile("avatar.png");
    appEvents.trigger("upload-mixin:chat-composer-uploader:add-files", image);
  });

  test("uploading files in composer does not insert placeholder text into chat composer", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-footer-buttons .btn.create");
    assert.ok(exists(".d-editor-input"), "the composer input is visible");

    this.container.lookup("service:chat").set("sidebarActive", false);
    this.container.lookup("service:chat").set("chatWindowFullPage", false);
    await click(".header-dropdown-toggle.open-chat");
    assert.ok(visible(".topic-chat-float-container"), "chat float is open");

    const appEvents = loggedInUser().appEvents;
    const done = assert.async();
    await fillIn(".d-editor-input", "The image:\n");

    appEvents.on("composer:all-uploads-complete", async () => {
      await settled();
      assert.strictEqual(
        query(".d-editor-input").value,
        "The image:\n![avatar.PNG|690x320](upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg)\n",
        "the topic composer gets the completed image markdown"
      );
      assert.strictEqual(
        query(".chat-composer-input").value,
        "",
        "the chat composer does not get the completed image markdown"
      );
      done();
    });

    appEvents.on("composer:upload-started", () => {
      assert.strictEqual(
        query(".d-editor-input").value,
        "The image:\n[Uploading: avatar.png...]()\n",
        "the topic composer gets the placeholder image markdown"
      );
      assert.strictEqual(
        query(".chat-composer-input").value,
        "",
        "the chat composer does not get the placeholder image markdown"
      );
    });

    const image = createFile("avatar.png");
    appEvents.trigger("composer:add-files", image);
  });
});

acceptance(
  "Discourse Chat - image uploads - uploads not allowed",
  function (needs) {
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
      chat_allow_uploads: false,
      discourse_local_dates_enabled: false,
    });
    needs.pretender((server, helper) => {
      baseChatPretenders(server, helper);
      directMessageChannelPretender(server, helper);
      chatChannelPretender(server, helper);
    });

    test("uploads are not allowed in public channels", async function (assert) {
      await visit("/chat/channel/4/public-category");
      await click(".chat-composer-dropdown__trigger-btn");

      assert.notOk(
        exists(".chat-composer-dropdown__item.chat-upload-btn"),
        "composer dropdown should not be visible because uploads are not enabled and no other buttons are rendered"
      );
    });

    test("uploads are not allowed in direct message channels", async function (assert) {
      await visit("/chat/channel/75/@hawk");
      await click(".chat-composer-dropdown__trigger-btn");

      assert.notOk(
        exists(".chat-composer-dropdown__item.chat-upload-btn"),
        "composer dropdown should not be visible because uploads are not enabled and no other buttons are rendered"
      );
    });
  }
);

acceptance("Discourse Chat - Insert Date", function (needs) {
  needs.user({
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });
  needs.settings({
    chat_enabled: true,
    discourse_local_dates_enabled: true,
  });
  needs.pretender((server, helper) => {
    baseChatPretenders(server, helper);
    chatChannelPretender(server, helper);
  });

  test("can use local date modal", async function (assert) {
    await visit("/chat/channel/4/public-category");
    await click(".chat-composer-dropdown__trigger-btn");
    await click(".chat-composer-dropdown__action-btn.local-dates");

    assert.ok(exists(".discourse-local-dates-create-modal"));

    await click(".modal-footer .btn-primary");

    assert.ok(
      query(".chat-composer-input").value.startsWith("[date"),
      "inserts date in composer input"
    );
  });
});

acceptance(
  "Discourse Chat - Channel Status - Read only channel",
  function (needs) {
    needs.user({
      admin: true,
      moderator: true,
      username: "eviltrout",
      id: 1,
      can_chat: true,
      has_chat_enabled: true,
    });
    needs.settings({
      chat_enabled: true,
    });
    needs.pretender((server, helper) => {
      baseChatPretenders(server, helper);
      chatChannelPretender(server, helper);
      server.get("/chat/chat_channels.json", () => {
        const cloned = cloneJSON(chatChannels);
        cloned.public_channels.find((chan) => chan.id === 7).status =
          CHANNEL_STATUSES.readOnly;
        return helper.response(cloned);
      });
    });

    test("read only channel composer is disabled", async function (assert) {
      await visit("/chat/channel/5/public-category");
      assert.strictEqual(query(".chat-composer-input").disabled, true);
    });

    test("read only channel header status shows correct information", async function (assert) {
      await visit("/chat/channel/5/public-category");
      assert.strictEqual(
        query(".chat-channel-status").innerText.trim(),
        I18n.t("chat.channel_status.read_only_header")
      );
    });

    test("read only channels do not show the reply, react, delete, edit, restore, or rebuild options for messages", async function (assert) {
      await visit("/chat/channel/5/public-category");
      await triggerEvent(".chat-message-container", "mouseenter");
      const dropdown = selectKit(".chat-msgactions .more-buttons");
      await dropdown.expand();
      assert.notOk(exists(".select-kit-row[data-value='edit']"));
      assert.notOk(exists(".select-kit-row[data-value='deleteMessage']"));
      assert.notOk(exists(".select-kit-row[data-value='rebakeMessage']"));
      assert.notOk(exists(".reply-btn"));
      assert.notOk(exists(".react-btn"));
    });
  }
);

acceptance(
  "Discourse Chat - Channel Status - Closed channel (regular user)",
  function (needs) {
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
      baseChatPretenders(server, helper);
      chatChannelPretender(server, helper);
      server.get("/chat/chat_channels.json", () => {
        const cloned = cloneJSON(chatChannels);
        cloned.public_channels.find((chan) => chan.id === 4).status =
          CHANNEL_STATUSES.closed;
        return helper.response(cloned);
      });
    });

    test("closed channel composer is disabled", async function (assert) {
      await visit("/chat/channel/4/public-category");
      assert.strictEqual(query(".chat-composer-input").disabled, true);
    });

    test("closed channel header status shows correct information", async function (assert) {
      await visit("/chat/channel/4/public-category");
      assert.strictEqual(
        query(".chat-channel-status").innerText.trim(),
        I18n.t("chat.channel_status.closed_header")
      );
    });

    test("closed channels do not show the reply, react, delete, edit, restore, or rebuild options for messages", async function (assert) {
      await visit("/chat/channel/4/public-category");

      await triggerEvent(".chat-message-container", "mouseenter");
      const dropdown = selectKit(".chat-msgactions .more-buttons");
      await dropdown.expand();

      assert.notOk(exists(".select-kit-row[data-value='edit']"));
      assert.notOk(exists(".select-kit-row[data-value='deleteMessage']"));
      assert.notOk(exists(".select-kit-row[data-value='rebakeMessage']"));
      assert.notOk(exists(".reply-btn"));
      assert.notOk(exists(".react-btn"));
    });
  }
);

acceptance(
  "Discourse Chat - Channel Status - Closed channel (staff user)",
  function (needs) {
    needs.user({
      admin: true,
      moderator: true,
      username: "eviltrout",
      id: 1,
      can_chat: true,
      has_chat_enabled: true,
    });
    needs.settings({
      chat_enabled: true,
    });
    needs.pretender((server, helper) => {
      baseChatPretenders(server, helper);
      chatChannelPretender(server, helper);
      server.get("/chat/chat_channels.json", () => {
        const cloned = cloneJSON(chatChannels);
        cloned.public_channels.find((chan) => chan.id === 7).status =
          CHANNEL_STATUSES.closed;
        return helper.response(cloned);
      });
    });

    test("closed channel composer is enabled", async function (assert) {
      await visit("/chat/channel/4/public-category");
      assert.strictEqual(query(".chat-composer-input").disabled, false);
    });

    test("closed channels show the reply, react, delete, edit, restore, or rebuild options for messages", async function (assert) {
      await visit("/chat/channel/4/public-category");
      await triggerEvent(".chat-message-container", "mouseenter");
      const dropdown = selectKit(".chat-msgactions .more-buttons");
      await dropdown.expand();
      assert.ok(
        exists(".select-kit-row[data-value='edit']"),
        "the edit message button is shown"
      );
      assert.ok(
        exists(".select-kit-row[data-value='deleteMessage']"),
        "the delete message button is shown"
      );
      assert.ok(
        exists(".select-kit-row[data-value='rebakeMessage']"),
        "the rebake message button is shown"
      );
      assert.ok(exists(".reply-btn", "the reply button is shown"));
      assert.ok(exists(".react-btn"), "the react button is shown");
    });
  }
);

acceptance("Discourse Chat - Channel Replying Indicator", function (needs) {
  needs.user({
    admin: true,
    moderator: true,
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });
  needs.settings({
    chat_enabled: true,
  });
  needs.pretender((server, helper) => {
    baseChatPretenders(server, helper);
    chatChannelPretender(server, helper);
    server.get("/chat/chat_channels.json", () => {
      const cloned = cloneJSON(chatChannels);
      cloned.public_channels.find((chan) => chan.id === 7).status =
        CHANNEL_STATUSES.closed;
      return helper.response(cloned);
    });
  });

  test("indicator content when replying/not replying", async function (assert) {
    const user = { id: 8, username: "bob" };
    await visit("/chat/channel/4/public-category");
    await joinChannel("/chat-reply/4", user);

    assert.equal(
      query(".chat-replying-indicator__text").innerText,
      I18n.t("chat.replying_indicator.single_user", {
        username: user.username,
      })
    );

    await leaveChannel("/chat-reply/4", user);

    assert.notOk(exists(".chat-replying-indicator__text"));
  });
});

acceptance("Discourse Chat - Direct Message Creator", function (needs) {
  needs.user({
    admin: true,
    moderator: true,
    username: "eviltrout",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });
  needs.settings({
    chat_enabled: true,
  });
  needs.pretender((server, helper) => {
    baseChatPretenders(server, helper);
    chatChannelPretender(server, helper);

    server.get("/u/search/users", () => {
      return helper.response([]);
    });
  });

  test("Create a direct message", async function (assert) {
    await visit("/latest");
    await click(".header-dropdown-toggle.open-chat");
    await click(".topic-chat-drawer-header__return-to-channels-btn");
    assert.ok(
      !exists(".new-dm.btn-floating"),
      "mobile floating button should not exist on desktop"
    );
    await click(".btn.new-dm");
    assert.ok(exists(".chat-draft"), "view changes to draft channel screen");
  });
});

acceptance("Discourse Chat - Drawer", function (needs) {
  needs.user({ has_chat_enabled: true });
  needs.settings({ chat_enabled: true });
  needs.pretender((server, helper) => {
    baseChatPretenders(server, helper);
    chatChannelPretender(server, helper);
  });

  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatService", {
      get: () => this.container.lookup("service:chat"),
    });
  });

  test("Position after closing reduced composer", async function (assert) {
    this.chatService.set("chatWindowFullPage", false);

    await visit("/t/internationalization-localization/280");
    await click(".btn.create");
    await click(".toggle-preview");
    await click(".header-dropdown-toggle.open-chat");
    await click(".save-or-cancel .cancel");
    const float = document.querySelector(".topic-chat-float-container");
    const key = "--composer-right";
    const value = getComputedStyle(float).getPropertyValue(key);

    assert.strictEqual(value, "15px");
  });
});

function createFile(name, type = "image/png") {
  // the blob content doesn't matter at all, just want it to be random-ish
  const file = new Blob([(Math.random() + 1).toString(36).substring(2)], {
    type,
  });
  file.name = name;
  return file;
}

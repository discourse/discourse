import {
  acceptance,
  emulateAutocomplete,
  loggedInUser,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { skip, test } from "qunit";
import { click, triggerEvent, visit, waitFor } from "@ember/test-helpers";
import pretender, { OK } from "discourse/tests/helpers/create-pretender";

acceptance("Chat | User status on mentions", function (needs) {
  const channelId = 1;
  const messageId = 1;
  const actingUser = {
    id: 1,
    username: "acting_user",
  };
  const mentionedUser1 = {
    id: 1000,
    username: "user1",
    status: {
      description: "surfing",
      emoji: "surfing_man",
    },
  };
  const mentionedUser2 = {
    id: 2000,
    username: "user2",
    status: {
      description: "vacation",
      emoji: "desert_island",
    },
  };
  const mentionedUser3 = {
    id: 3000,
    username: "user3",
    status: {
      description: "off to dentist",
      emoji: "tooth",
    },
  };
  const message = {
    id: messageId,
    message: `Hey @${mentionedUser1.username}`,
    cooked: `<p>Hey <a class="mention" href="/u/${mentionedUser1.username}">@${mentionedUser1.username}</a></p>`,
    mentioned_users: [mentionedUser1],
    user: actingUser,
  };
  const newStatus = {
    description: "working remotely",
    emoji: "house",
  };
  const channel = {
    id: channelId,
    chatable_id: 1,
    chatable_type: "Category",
    meta: { message_bus_last_ids: {} },
    current_user_membership: { following: true },
    chatable: { id: 1 },
  };

  needs.settings({ chat_enabled: true });

  needs.user({
    ...actingUser,
    has_chat_enabled: true,
    chat_channels: {
      public_channels: [channel],
      direct_message_channels: [],
      meta: { message_bus_last_ids: {} },
      tracking: {},
    },
  });

  needs.hooks.beforeEach(function () {
    pretender.post(`/chat/1`, () => OK());
    pretender.put(`/chat/1/edit/${messageId}`, () => OK());
    pretender.post(`/chat/drafts`, () => OK());
    pretender.put(`/chat/api/channels/1/read/1`, () => OK());
    pretender.delete(`/chat/api/channels/1/messages/${messageId}`, () => OK());
    pretender.put(`/chat/api/channels/1/messages/${messageId}/restore`, () =>
      OK()
    );

    pretender.get(`/chat/api/channels/1`, () =>
      OK({
        channel,
        chat_messages: [message],
        meta: { can_delete_self: true },
      })
    );

    setupAutocompleteResponses([mentionedUser2, mentionedUser3]);
  });

  skip("just posted messages | it shows status on mentions ", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);
    await typeWithAutocompleteAndSend(`mentioning @${mentionedUser2.username}`);
    assertStatusIsRendered(
      assert,
      statusSelector(mentionedUser2.username),
      mentionedUser2.status
    );
  });

  skip("just posted messages | it updates status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);
    await typeWithAutocompleteAndSend(`mentioning @${mentionedUser2.username}`);

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser2.id]: newStatus,
    });

    const selector = statusSelector(mentionedUser2.username);
    await waitFor(selector);
    assertStatusIsRendered(assert, selector, newStatus);
  });

  skip("just posted messages | it deletes status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await typeWithAutocompleteAndSend(`mentioning @${mentionedUser2.username}`);

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser2.id]: null,
    });

    const selector = statusSelector(mentionedUser2.username);
    await waitFor(selector, { count: 0 });
    assert.dom(selector).doesNotExist("status is deleted");
  });

  skip("edited messages | it shows status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await editMessage(
      ".chat-message-content",
      `mentioning @${mentionedUser3.username}`
    );

    assertStatusIsRendered(
      assert,
      statusSelector(mentionedUser3.username),
      mentionedUser3.status
    );
  });

  skip("edited messages | it updates status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);
    await editMessage(
      ".chat-message-content",
      `mentioning @${mentionedUser3.username}`
    );

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser3.id]: newStatus,
    });

    const selector = statusSelector(mentionedUser3.username);
    await waitFor(selector);
    assertStatusIsRendered(assert, selector, newStatus);
  });

  skip("edited messages | it deletes status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await editMessage(
      ".chat-message-content",
      `mentioning @${mentionedUser3.username}`
    );

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser3.id]: null,
    });

    const selector = statusSelector(mentionedUser3.username);
    await waitFor(selector, { count: 0 });
    assert.dom(selector).doesNotExist("status is deleted");
  });

  test("deleted messages | it shows status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await deleteMessage(".chat-message-content");
    await click(".chat-message-expand");

    assertStatusIsRendered(
      assert,
      statusSelector(mentionedUser1.username),
      mentionedUser1.status
    );
  });

  test("deleted messages | it updates status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await deleteMessage(".chat-message-content");
    await click(".chat-message-expand");

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser1.id]: newStatus,
    });

    const selector = statusSelector(mentionedUser1.username);
    await waitFor(selector);
    assertStatusIsRendered(assert, selector, newStatus);
  });

  test("deleted messages | it deletes status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await deleteMessage(".chat-message-content");
    await click(".chat-message-expand");

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser1.id]: null,
    });

    const selector = statusSelector(mentionedUser1.username);
    await waitFor(selector, { count: 0 });
    assert.dom(selector).doesNotExist("status is deleted");
  });

  test("restored messages | it shows status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await deleteMessage(".chat-message-content");
    await restoreMessage(".chat-message-deleted");

    assertStatusIsRendered(
      assert,
      statusSelector(mentionedUser1.username),
      mentionedUser1.status
    );
  });

  test("restored messages | it updates status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await deleteMessage(".chat-message-content");
    await restoreMessage(".chat-message-deleted");

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser1.id]: newStatus,
    });

    const selector = statusSelector(mentionedUser1.username);
    await waitFor(selector);
    assertStatusIsRendered(assert, selector, newStatus);
  });

  test("restored messages | it deletes status on mentions", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await deleteMessage(".chat-message-content");
    await restoreMessage(".chat-message-deleted");

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser1.id]: null,
    });

    const selector = statusSelector(mentionedUser1.username);
    await waitFor(selector, { count: 0 });
    assert.dom(selector).doesNotExist("status is deleted");
  });

  function assertStatusIsRendered(assert, selector, status) {
    assert
      .dom(selector)
      .exists("status is rendered")
      .hasAttribute(
        "title",
        status.description,
        "status description is updated"
      )
      .hasAttribute(
        "src",
        new RegExp(`${status.emoji}.png`),
        "status emoji is updated"
      );
  }

  async function deleteMessage(messageSelector) {
    await triggerEvent(query(messageSelector), "mouseenter");
    await click(".more-buttons .select-kit-header-wrapper");
    await click(".select-kit-collection .select-kit-row[data-value='delete']");
    await publishToMessageBus(`/chat/${channelId}`, {
      type: "delete",
      deleted_id: messageId,
      deleted_at: "2022-01-01T08:00:00.000Z",
    });
  }

  async function editMessage(messageSelector, text) {
    await triggerEvent(query(messageSelector), "mouseenter");
    await click(".more-buttons .select-kit-header-wrapper");
    await click(".select-kit-collection .select-kit-row[data-value='edit']");
    await typeWithAutocompleteAndSend(text);
  }

  async function restoreMessage(messageSelector) {
    await triggerEvent(query(messageSelector), "mouseenter");
    await click(".more-buttons .select-kit-header-wrapper");
    await click(".select-kit-collection .select-kit-row[data-value='restore']");
    await publishToMessageBus(`/chat/${channelId}`, {
      type: "restore",
      chat_message: message,
    });
  }

  async function typeWithAutocompleteAndSend(text) {
    await emulateAutocomplete(".chat-composer__input", text);
    await click(".autocomplete.ac-user .selected");
    await click(".chat-composer-button.-send");
  }

  function setupAutocompleteResponses(results) {
    pretender.get("/u/search/users", () => {
      return [
        200,
        {},
        {
          users: results,
        },
      ];
    });

    pretender.get("/chat/api/mentions/groups.json", () => {
      return [
        200,
        {},
        {
          unreachable: [],
          over_members_limit: [],
          invalid: ["and"],
        },
      ];
    });
  }

  function statusSelector(username) {
    return `.mention[href='/u/${username}'] .user-status`;
  }
});

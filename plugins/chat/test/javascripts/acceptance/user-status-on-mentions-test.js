import {
  acceptance,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import {
  click,
  fillIn,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import pretender from "discourse/tests/helpers/create-pretender";

acceptance("Chat | User status on mentions", function (needs) {
  const channelId = 1;
  const mentionedUser1 = {
    id: 1000,
    username: "user1",
    status: {
      description: "surfing",
      emoji: "surfing_man",
    },
  };
  const messagesResponse = {
    meta: {
      channel_id: channelId,
    },
    chat_messages: [
      {
        id: 1891,
        message: `Hey @${mentionedUser1.username}`,
        cooked: `<p>Hey <a class="mention" href="/u/${mentionedUser1.username}">@${mentionedUser1.username}</a></p>`,
        mentioned_users: [mentionedUser1],
        user: {
          id: 1,
          username: "jesse",
        },
      },
    ],
  };
  const mentionedUser2 = {
    id: 2000,
    username: "user2",
    status: {
      description: "vacation",
      emoji: "desert_island",
    },
  };

  needs.settings({ chat_enabled: true });

  needs.user({
    has_chat_enabled: true,
    chat_channels: {
      public_channels: [
        {
          id: channelId,
          chatable_id: 1,
          chatable_type: "Category",
          meta: { message_bus_last_ids: {} },
          current_user_membership: { following: true },
          chatable: { id: 1 },
        },
      ],
      direct_message_channels: [],
      meta: { message_bus_last_ids: {} },
    },
  });

  needs.hooks.beforeEach(function () {
    pretender.get("/chat/1/messages", () => {
      return [200, {}, messagesResponse];
    });
    pretender.post("/chat/1", () => {
      return [200, {}, {}];
    });
    pretender.post("/chat/drafts", () => {
      return [200, {}, {}];
    });

    setupAutocompleteResponses([mentionedUser2]);
  });

  test("it shows status on mentions on just posted messages", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);
    await typeAndApplyAutocompleteSuggestion("mentioning @u");

    assert
      .dom(`.mention[href='/u/${mentionedUser2.username}'] .user-status`)
      .exists("status is rendered")
      .hasAttribute(
        "title",
        mentionedUser2.status.description,
        "status description is correct"
      )
      .hasAttribute(
        "src",
        new RegExp(`${mentionedUser2.status.emoji}.png`),
        "status emoji is updated"
      );
  });

  test("it updates status on mentions on just posted messages", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);
    await typeAndApplyAutocompleteSuggestion("mentioning @u");

    const newStatus = {
      description: "working remotely",
      emoji: "house",
    };

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser2.id]: newStatus,
    });

    const selector = `.mention[href='/u/${mentionedUser2.username}'] .user-status`;
    await waitFor(selector);
    assert
      .dom(selector)
      .exists("status is rendered")
      .hasAttribute(
        "title",
        newStatus.description,
        "status description is updated"
      )
      .hasAttribute(
        "src",
        new RegExp(`${newStatus.emoji}.png`),
        "status emoji is updated"
      );
  });

  test("it deletes status on mentions on just posted messages", async function (assert) {
    await visit(`/chat/c/-/${channelId}`);

    await typeAndApplyAutocompleteSuggestion("mentioning @u");

    loggedInUser().appEvents.trigger("user-status:changed", {
      [mentionedUser2.id]: null,
    });

    const selector = `.mention[href='/u/${mentionedUser2.username}'] .user-status`;
    await waitFor(selector, { count: 0 });
    assert.dom(selector).doesNotExist("status is deleted");
  });

  async function emulateAutocomplete(inputSelector, text) {
    await triggerKeyEvent(inputSelector, "keydown", "Backspace");
    await fillIn(inputSelector, `${text} `);
    await triggerKeyEvent(inputSelector, "keyup", "Backspace");

    await triggerKeyEvent(inputSelector, "keydown", "Backspace");
    await fillIn(inputSelector, text);
    await triggerKeyEvent(inputSelector, "keyup", "Backspace");
  }

  async function typeAndApplyAutocompleteSuggestion(text) {
    await emulateAutocomplete(".chat-composer__input", text);
    await click(".autocomplete.ac-user .selected");
    await triggerKeyEvent(".chat-composer__input", "keydown", "Enter");
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
});

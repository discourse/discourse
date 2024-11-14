import { getOwner } from "@ember/owner";
import { render, triggerEvent, waitFor } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | chat-channel | status on mentions",
  function (hooks) {
    setupRenderingTest(hooks);

    const channelId = 1;
    const actingUser = {
      id: 1,
      username: "acting_user",
    };
    const mentionedUser = {
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
    const message = {
      id: 1891,
      message: `Hey @${mentionedUser.username}`,
      cooked: `<p>Hey <a class="mention" href="/u/${mentionedUser.username}">@${mentionedUser.username}</a></p>`,
      mentioned_users: [mentionedUser],
      created_at: "2020-08-04T15:00:00.000Z",
      user: {
        id: 1,
        username: "jesse",
      },
    };

    hooks.beforeEach(function () {
      pretender.get(`/chat/api/channels/1/messages`, () =>
        response({
          messages: [message],
          meta: { can_delete_self: true },
        })
      );
      pretender.get(`/chat/api/me/channels`, () =>
        response({
          direct_message_channels: [],
          public_channels: [],
        })
      );

      this.channel = new ChatFabricators(getOwner(this)).channel({
        id: channelId,
        currentUserMembership: { following: true },
        meta: { can_join_chat_channel: false },
      });
      this.appEvents = this.container.lookup("service:app-events");
    });

    test("it shows status on mentions", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} />`);

      assertStatusIsRendered(
        assert,
        statusSelector(mentionedUser.username),
        mentionedUser.status
      );
    });

    test("it updates status on mentions", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} />`);

      const newStatus = {
        description: "off to dentist",
        emoji: "tooth",
      };

      this.appEvents.trigger("user-status:changed", {
        [mentionedUser.id]: newStatus,
      });

      const selector = statusSelector(mentionedUser.username);
      await waitFor(selector);

      assertStatusIsRendered(
        assert,
        statusSelector(mentionedUser.username),
        newStatus
      );
    });

    test("it deletes status on mentions", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} />`);

      this.appEvents.trigger("user-status:changed", {
        [mentionedUser.id]: null,
      });

      const selector = statusSelector(mentionedUser.username);
      await waitFor(selector, { count: 0 });
      assert.dom(selector).doesNotExist("status is deleted");
    });

    test("it shows status on mentions on messages that came from Message Bus", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} />`);

      await receiveChatMessageViaMessageBus();

      assertStatusIsRendered(
        assert,
        statusSelector(mentionedUser2.username),
        mentionedUser2.status
      );
    });

    test("it updates status on mentions on messages that came from Message Bus", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} />`);
      await receiveChatMessageViaMessageBus();

      const newStatus = {
        description: "off to meeting",
        emoji: "calendar",
      };
      this.appEvents.trigger("user-status:changed", {
        [mentionedUser2.id]: newStatus,
      });

      const selector = statusSelector(mentionedUser2.username);
      await waitFor(selector);
      assertStatusIsRendered(
        assert,
        statusSelector(mentionedUser2.username),
        newStatus
      );
    });

    test("it deletes status on mentions on messages that came from Message Bus", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} />`);
      await receiveChatMessageViaMessageBus();

      this.appEvents.trigger("user-status:changed", {
        [mentionedUser2.id]: null,
      });

      const selector = statusSelector(mentionedUser2.username);
      await waitFor(selector, { count: 0 });
      assert.dom(selector).doesNotExist("status is deleted");
    });

    test("it shows status tooltip", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} /><DTooltips />`);
      await triggerEvent(statusSelector(mentionedUser.username), "mousemove");

      assert
        .dom(".user-status-tooltip-description")
        .hasText(
          mentionedUser.status.description,
          "status description is correct"
        );

      assert
        .dom(
          `.user-status-message-tooltip img[alt='${mentionedUser.status.emoji}']`
        )
        .exists("status emoji is correct");
    });

    function assertStatusIsRendered(assert, selector, status) {
      assert
        .dom(selector)
        .exists("status is rendered")
        .hasAttribute(
          "src",
          new RegExp(`${status.emoji}.png`),
          "status emoji is updated"
        );
    }

    async function receiveChatMessageViaMessageBus() {
      await publishToMessageBus(`/chat/${channelId}`, {
        chat_message: {
          id: 2138,
          message: `Hey @${mentionedUser2.username}`,
          cooked: `<p>Hey <a class="mention" href="/u/${mentionedUser2.username}">@${mentionedUser2.username}</a></p>`,
          created_at: "2023-05-18T16:07:59.588Z",
          excerpt: `Hey @${mentionedUser2.username}`,
          available_flags: [],
          chat_channel_id: 7,
          mentioned_users: [mentionedUser2],
          user: actingUser,
          chat_webhook_event: null,
          uploads: [],
        },
        type: "sent",
      });
    }

    function statusSelector(username) {
      return `.mention[href='/u/${username}'] .user-status-message img`;
    }
  }
);

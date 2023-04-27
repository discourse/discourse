import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import fabricators from "../helpers/fabricators";
import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";

module(
  "Discourse Chat | Component | chat-channel | mentions",
  function (hooks) {
    setupRenderingTest(hooks);

    const channelId = 1;
    const mentionedUser = {
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
          message: `Hey @${mentionedUser.username}`,
          cooked: `<p>Hey <a class="mention" href="/u/${mentionedUser.username}">@${mentionedUser.username}</a></p>`,
          mentioned_users: [mentionedUser],
          user: {
            id: 1,
            username: "jesse",
          },
        },
      ],
    };

    hooks.beforeEach(function () {
      this.channel = fabricators.chatChannel({
        id: channelId,
        currentUserMembership: { following: true },
      });

      pretender.get(`/chat/${channelId}/messages`, () => {
        return [200, {}, messagesResponse];
      });
      pretender.post(`/chat/${channelId}`, () => {
        return [200, {}, {}];
      });
      pretender.post("/chat/drafts", () => {
        return [200, {}, {}];
      });

      this.appEvents = this.container.lookup("service:appEvents");
    });

    test("it shows status on mentions", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} />`);

      assert
        .dom(".mention .user-status")
        .exists("status is rendered")
        .hasAttribute(
          "title",
          mentionedUser.status.description,
          "status description is correct"
        )
        .hasAttribute(
          "src",
          new RegExp(`${mentionedUser.status.emoji}.png`),
          "status emoji is updated"
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

      const selector = ".mention .user-status";
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

    test("it deletes status on mentions", async function (assert) {
      await render(hbs`<ChatChannel @channel={{this.channel}} />`);

      this.appEvents.trigger("user-status:changed", {
        [mentionedUser.id]: null,
      });

      const selector = ".mention .user-status";
      await waitFor(selector, { count: 0 });
      assert.dom(selector).doesNotExist("status is deleted");
    });
  }
);

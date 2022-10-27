import I18n from "I18n";
import { test } from "qunit";

import { click, visit } from "@ember/test-helpers";

import {
  acceptance,
  exists,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

import {
  baseChatPretenders,
  chatChannelPretender,
} from "../helpers/chat-pretenders";

acceptance(
  "Discourse Chat - experiment user menu notifications - user cannot chat",
  function (needs) {
    needs.user({ has_chat_enabled: false });
    needs.settings({ chat_enabled: false });

    test("chat notifications tab is not displayed in user menu", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user");

      assert.notOk(
        exists("#user-menu-button-chat-notifications"),
        "button for chat notifications tab is not displayed"
      );
    });
  }
);

acceptance(
  "Discourse Chat - experimental user menu notifications ",
  function (needs) {
    needs.user({ redesigned_user_menu_enabled: true, has_chat_enabled: true });
    needs.settings({ chat_enabled: true });

    needs.pretender((server, helper) => {
      baseChatPretenders(server, helper);
      chatChannelPretender(server, helper);
    });

    test("chat notifications tab", async function (assert) {
      updateCurrentUser({
        grouped_unread_notifications: {
          29: 3, // chat_mention notification type
          31: 1, // chat_invitation notification type
        },
      });

      await visit("/");
      await click(".header-dropdown-toggle.current-user");

      assert.ok(
        exists("#user-menu-button-chat-notifications"),
        "button for chat notifications tab is displayed"
      );

      assert.ok(
        exists("#user-menu-button-chat-notifications .d-icon-comment"),
        "displays the comment icon for chat notification tab button"
      );

      assert.strictEqual(
        query("#user-menu-button-chat-notifications .badge-notification")
          .textContent,
        "4",
        "displays the right badge count for chat notifications tab button"
      );
    });

    test("chat mention notification link", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user");

      const chatMentionNotificationLink = queryAll(".chat-mention a")[0];

      assert.strictEqual(
        chatMentionNotificationLink.textContent
          .trim()
          .replace(/\n/g, "")
          .replace(/\s+/, " "),
        'hawk mentioned you in "Site"',
        "displays the right text for notification"
      );

      assert.ok(
        exists(chatMentionNotificationLink.querySelector(".d-icon-comment")),
        "displays the right icon for the notification"
      );

      assert.strictEqual(
        chatMentionNotificationLink.title,
        I18n.t("notifications.titles.chat_mention"),
        "has the right title attribute for notification link"
      );

      assert.ok(
        chatMentionNotificationLink.href.endsWith(
          "/chat/channel/9/site?messageId=174"
        ),
        "has the right href attribute for notification link"
      );
    });

    test("personal chat mention notification link", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user");

      const personalChatMentionNotificationLink =
        queryAll(".chat-mention a")[3];

      assert.strictEqual(
        personalChatMentionNotificationLink.textContent
          .trim()
          .replace(/\n/g, "")
          .replace(/\s+/, " "),
        "hawk mentioned you in personal chat",
        "displays the right text for notification"
      );

      assert.ok(
        exists(
          personalChatMentionNotificationLink.querySelector(".d-icon-comment")
        ),
        "displays the right icon for the notification"
      );

      assert.strictEqual(
        personalChatMentionNotificationLink.title,
        I18n.t("notifications.titles.chat_mention"),
        "has the right title attribute for notification link"
      );

      assert.ok(
        personalChatMentionNotificationLink.href.endsWith(
          "/chat/channel/9/site?messageId=174"
        ),
        "has the right href attribute for notification link"
      );
    });

    test("chat group mention notification link", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user");

      const chatGroupMentionNotificationLink = queryAll(".chat-mention a")[1];

      assert.strictEqual(
        chatGroupMentionNotificationLink.textContent
          .trim()
          .replace(/\n/g, "")
          .replace(/\s+/, " "),
        'hawk mentioned @engineers in "Site"',
        "displays the right text for notification"
      );

      assert.ok(
        exists(
          chatGroupMentionNotificationLink.querySelector(".d-icon-comment")
        ),
        "displays the right icon for the notification"
      );

      assert.strictEqual(
        chatGroupMentionNotificationLink.title,
        I18n.t("notifications.titles.chat_mention"),
        "has the right title attribute for notification link"
      );

      assert.ok(
        chatGroupMentionNotificationLink.href.endsWith(
          "/chat/channel/9/site?messageId=174"
        ),
        "has the right href attribute for notification link"
      );
    });

    test("chat all mention notification link", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user");

      const chatAllMentionNotificationLink = queryAll(".chat-mention a")[2];

      assert.strictEqual(
        chatAllMentionNotificationLink.textContent
          .trim()
          .replace(/\n/g, "")
          .replace(/\s+/, " "),
        'hawk mentioned @all in "Site"',
        "displays the right text for notification"
      );

      assert.ok(
        exists(chatAllMentionNotificationLink.querySelector(".d-icon-comment")),
        "displays the right icon for the notification"
      );

      assert.strictEqual(
        chatAllMentionNotificationLink.title,
        I18n.t("notifications.titles.chat_mention"),
        "has the right title attribute for notification link"
      );

      assert.ok(
        chatAllMentionNotificationLink.href.endsWith(
          "/chat/channel/9/site?messageId=174"
        ),
        "has the right href attribute for notification link"
      );
    });

    test("chat invite notification link", async function (assert) {
      await visit("/");
      await click(".header-dropdown-toggle.current-user");

      const chatInviteNotificationLink = queryAll(".chat-invitation a")[0];

      assert.strictEqual(
        chatInviteNotificationLink.textContent
          .trim()
          .replace(/\n/g, "")
          .replace(/\s+/, " "),
        "hawk invited you to join a chat channel",
        "displays the right text for notification"
      );

      assert.ok(
        exists(chatInviteNotificationLink.querySelector(".d-icon-link")),
        "displays the right icon for the notification"
      );

      assert.strictEqual(
        chatInviteNotificationLink.title,
        I18n.t("notifications.titles.chat_invitation"),
        "has the right title attribute for notification link"
      );

      assert.ok(
        chatInviteNotificationLink.href.endsWith(
          "/chat/channel/9/site?messageId=174"
        ),
        "has the right href attribute for notification link"
      );
    });
  }
);

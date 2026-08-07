import {
  click,
  currentRouteName,
  currentURL,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Chat | Disabled in preferences", function (needs) {
  needs.user();
  needs.settings({ chat_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/notifications", () =>
      helper.response({
        notifications: [
          {
            id: 1,
            user_id: 1,
            notification_type: NOTIFICATION_TYPES.chat_invitation,
            read: false,
            high_priority: true,
            created_at: "2026-01-01T00:00:00.000Z",
            data: {
              chat_channel_id: 9,
              chat_channel_title: "Design",
              chat_channel_slug: "design",
              invited_by_username: "alice",
              chat_message_id: 5,
            },
          },
        ],
        total_rows_notifications: 1,
        seen_notification_id: 0,
      })
    );
  });

  test("shows an empty state instead of redirecting to the homepage", async function (assert) {
    updateCurrentUser({ can_chat: true, has_chat_enabled: false });

    await visit("/chat/c/design/9/5");

    assert.strictEqual(
      currentRouteName(),
      "chat.disabled",
      "lands on the chat disabled route rather than bouncing home"
    );
    assert
      .dom(".chat-disabled .empty-state__title")
      .hasText(i18n("chat.disabled.title"));
    assert
      .dom(".chat-disabled .empty-state__cta a")
      .hasAttribute(
        "href",
        /\/my\/preferences\/chat$/,
        "the call to action links to chat preferences"
      );
  });

  test("clicking a chat notification lands on the disabled page", async function (assert) {
    updateCurrentUser({ can_chat: true, has_chat_enabled: false });

    await visit("/");
    await click("#toggle-current-user");
    await click(".user-menu .notification.chat-invitation a");

    assert.strictEqual(
      currentURL(),
      "/chat/disabled",
      "clicking the chat notification lands on the disabled page"
    );
  });
});

import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { render } from "@ember/test-helpers";
import { deepMerge } from "discourse-common/lib/object";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import Notification from "discourse/models/notification";
import hbs from "htmlbars-inline-precompile";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";
import I18n from "I18n";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        notification_type: NOTIFICATION_TYPES.chat_invitation,
        read: false,
        data: {
          message: "chat.mention_notification",
          mentioned_by_username: "eviltrout",
          chat_channel_id: 9,
          chat_message_id: 2,
          chat_channel_title: "Site",
        },
      },
      overrides
    )
  );
}

module(
  "Discourse Chat | Widget | chat-mention-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    test("generated link", async function (assert) {
      this.set("args", getNotification());
      const data = this.args.data;
      await render(
        hbs`<MountWidget @widget="chat-mention-notification-item" @args={{this.args}} />`
      );

      assert.strictEqual(
        query(".chat-invitation a div").innerHTML.trim(),
        I18n.t("notifications.popup.chat_mention.direct_html", {
          username: "eviltrout",
          identifier: null,
          channel: "Site",
        })
      );

      assert.strictEqual(
        query(".chat-invitation a").getAttribute("href"),
        `/chat/c/${slugifyChannel({
          title: data.chat_channel_title,
        })}/${data.chat_channel_id}/${data.chat_message_id}`
      );
    });
  }
);

module(
  "Discourse Chat | Widget | chat-group-mention-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    test("generated link", async function (assert) {
      this.set(
        "args",
        getNotification({
          data: {
            mentioned_by_username: "eviltrout",
            identifier: "moderators",
          },
        })
      );
      const data = this.args.data;
      await render(
        hbs`<MountWidget @widget="chat-group-mention-notification-item" @args={{this.args}} />`
      );

      assert.strictEqual(
        query(".chat-invitation a div").innerHTML.trim(),
        I18n.t("notifications.popup.chat_mention.other_html", {
          username: "eviltrout",
          identifier: "@moderators",
          channel: "Site",
        })
      );

      assert.strictEqual(
        query(".chat-invitation a").getAttribute("href"),
        `/chat/c/${slugifyChannel({
          title: data.chat_channel_title,
        })}/${data.chat_channel_id}/${data.chat_message_id}`
      );
    });
  }
);

module(
  "Discourse Chat | Widget | chat-group-mention-notification-item (@all)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("generated link", async function (assert) {
      this.set(
        "args",
        getNotification({
          data: {
            mentioned_by_username: "eviltrout",
            identifier: "all",
          },
        })
      );
      const data = this.args.data;
      await render(
        hbs`<MountWidget @widget="chat-group-mention-notification-item" @args={{this.args}} />`
      );

      assert.strictEqual(
        query(".chat-invitation a div").innerHTML.trim(),
        I18n.t("notifications.popup.chat_mention.other_html", {
          username: "eviltrout",
          identifier: "@all",
          channel: "Site",
        })
      );

      assert.strictEqual(
        query(".chat-invitation a").getAttribute("href"),
        `/chat/c/${slugifyChannel({
          title: data.chat_channel_title,
        })}/${data.chat_channel_id}/${data.chat_message_id}`
      );
    });
  }
);

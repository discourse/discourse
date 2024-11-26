import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from 'discourse-i18n';
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

module(
  "Discourse Chat | Component | chat-retention-reminder",
  function (hooks) {
    setupRenderingTest(hooks);

    test("display retention info", async function (assert) {
      this.channel = ChatChannel.create({ chatable_type: "Category" });
      this.currentUser.set("needs_channel_retention_reminder", true);

      await render(hbs`<ChatRetentionReminder @channel={{this.channel}} />`);

      assert.dom(".chat-retention-reminder").includesText(
        i18n("chat.retention_reminders.long", {
          count: this.siteSettings.chat_channel_retention_days,
        })
      );
    });

    test("@type=short", async function (assert) {
      this.channel = ChatChannel.create({ chatable_type: "Category" });
      this.currentUser.set("needs_channel_retention_reminder", true);

      await render(
        hbs`<ChatRetentionReminder @channel={{this.channel}} @type="short" />`
      );

      assert.dom(".chat-retention-reminder").includesText(
        i18n("chat.retention_reminders.short", {
          count: this.siteSettings.chat_channel_retention_days,
        })
      );
    });
  }
);

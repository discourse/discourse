import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatRetentionReminder from "discourse/plugins/chat/discourse/components/chat-retention-reminder";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

module(
  "Discourse Chat | Component | chat-retention-reminder",
  function (hooks) {
    setupRenderingTest(hooks);

    test("display retention info", async function (assert) {
      const self = this;

      this.channel = ChatChannel.create({ chatable_type: "Category" });
      this.currentUser.set("needs_channel_retention_reminder", true);

      await render(
        <template><ChatRetentionReminder @channel={{self.channel}} /></template>
      );

      assert.dom(".chat-retention-reminder").includesText(
        i18n("chat.retention_reminders.long", {
          count: this.siteSettings.chat_channel_retention_days,
        })
      );
    });

    test("@type=short", async function (assert) {
      const self = this;

      this.channel = ChatChannel.create({ chatable_type: "Category" });
      this.currentUser.set("needs_channel_retention_reminder", true);

      await render(
        <template>
          <ChatRetentionReminder @channel={{self.channel}} @type="short" />
        </template>
      );

      assert.dom(".chat-retention-reminder").includesText(
        i18n("chat.retention_reminders.short", {
          count: this.siteSettings.chat_channel_retention_days,
        })
      );
    });
  }
);

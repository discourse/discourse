import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatRetentionReminderText from "discourse/plugins/chat/discourse/components/chat-retention-reminder-text";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | chat-retention-reminder-text",
  function (hooks) {
    setupRenderingTest(hooks);

    test("when setting is set on 0", async function (assert) {
      const self = this;

      this.channel = new ChatFabricators(getOwner(this)).channel();
      this.siteSettings.chat_channel_retention_days = 0;

      await render(
        <template>
          <ChatRetentionReminderText @channel={{self.channel}} />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.indefinitely_long"));

      await render(
        <template>
          <ChatRetentionReminderText @channel={{self.channel}} @type="short" />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.indefinitely_short"));
    });

    test("when channel is a public channel", async function (assert) {
      const self = this;

      this.channel = new ChatFabricators(getOwner(this)).channel();
      this.siteSettings.chat_channel_retention_days = 10;

      await render(
        <template>
          <ChatRetentionReminderText @channel={{self.channel}} />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.long", { count: 10 }));

      await render(
        <template>
          <ChatRetentionReminderText @channel={{self.channel}} @type="short" />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.short", { count: 10 }));
    });

    test("when channel is a DM channel", async function (assert) {
      const self = this;

      this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();
      this.siteSettings.chat_dm_retention_days = 10;

      await render(
        <template>
          <ChatRetentionReminderText @channel={{self.channel}} />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.long", { count: 10 }));

      await render(
        <template>
          <ChatRetentionReminderText @channel={{self.channel}} @type="short" />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.short", { count: 10 }));
    });
  }
);

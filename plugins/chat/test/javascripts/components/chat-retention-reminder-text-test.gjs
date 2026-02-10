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
      this.channel = new ChatFabricators(getOwner(this)).channel();
      this.siteSettings.chat_channel_retention_days = 0;

      await render(
        <template>
          <ChatRetentionReminderText @channel={{this.channel}} />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText("retain channel messages indefinitely");

      await render(
        <template>
          <ChatRetentionReminderText @channel={{this.channel}} @type="short" />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.indefinitely_short"));
    });

    test("when channel is a public channel", async function (assert) {
      this.channel = new ChatFabricators(getOwner(this)).channel();
      this.siteSettings.chat_channel_retention_days = 10;

      await render(
        <template>
          <ChatRetentionReminderText @channel={{this.channel}} />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText("retain channel messages for 10 days");

      await render(
        <template>
          <ChatRetentionReminderText @channel={{this.channel}} @type="short" />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.short", { count: 10 }));
    });

    test("when channel is a DM channel", async function (assert) {
      this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();
      this.siteSettings.chat_dm_retention_days = 10;

      await render(
        <template>
          <ChatRetentionReminderText @channel={{this.channel}} />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText("retain channel messages for 10 days");

      await render(
        <template>
          <ChatRetentionReminderText @channel={{this.channel}} @type="short" />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text")
        .includesText(i18n("chat.retention_reminders.short", { count: 10 }));
    });

    test("links to chat settings for admins", async function (assert) {
      this.currentUser.admin = true;
      this.channel = new ChatFabricators(getOwner(this)).channel();
      this.siteSettings.chat_channel_retention_days = 0;

      await render(
        <template>
          <ChatRetentionReminderText @channel={{this.channel}} />
        </template>
      );

      assert
        .dom(".chat-retention-reminder-text a")
        .hasAttribute("href", "/admin/site_settings/category/chat");
    });

    test("does not link to chat settings for non-admins", async function (assert) {
      this.currentUser.admin = false;
      this.channel = new ChatFabricators(getOwner(this)).channel();
      this.siteSettings.chat_channel_retention_days = 0;

      await render(
        <template>
          <ChatRetentionReminderText @channel={{this.channel}} />
        </template>
      );

      assert.dom(".chat-retention-reminder-text a").doesNotExist();
    });
  }
);

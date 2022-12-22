import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module(
  "Discourse Chat | Component | chat-retention-reminder",
  function (hooks) {
    setupRenderingTest(hooks);

    test("Shows for public channels when user needs it", async function (assert) {
      this.set(
        "chatChannel",
        ChatChannel.create({ chatable_type: "Category" })
      );
      this.currentUser.set("needs_channel_retention_reminder", true);
      this.siteSettings.chat_channel_retention_days = 100;

      await render(
        hbs`<ChatRetentionReminder @chatChannel={{this.chatChannel}} />`
      );

      assert.strictEqual(
        query(".chat-retention-reminder-text").innerText.trim(),
        I18n.t("chat.retention_reminders.public", { days: 100 })
      );
    });

    test("Doesn't show for public channels when user has dismissed it", async function (assert) {
      this.set(
        "chatChannel",
        ChatChannel.create({ chatable_type: "Category" })
      );
      this.currentUser.set("needs_channel_retention_reminder", false);
      this.siteSettings.chat_channel_retention_days = 100;

      await render(
        hbs`<ChatRetentionReminder @chatChannel={{this.chatChannel}} />`
      );

      assert.false(exists(".chat-retention-reminder"));
    });

    test("Shows for direct message channels when user needs it", async function (assert) {
      this.set(
        "chatChannel",
        ChatChannel.create({ chatable_type: "DirectMessage" })
      );
      this.currentUser.set("needs_dm_retention_reminder", true);
      this.siteSettings.chat_dm_retention_days = 100;

      await render(
        hbs`<ChatRetentionReminder @chatChannel={{this.chatChannel}} />`
      );

      assert.strictEqual(
        query(".chat-retention-reminder-text").innerText.trim(),
        I18n.t("chat.retention_reminders.dm", { days: 100 })
      );
    });

    test("Doesn't show for dm channels when user has dismissed it", async function (assert) {
      this.set(
        "chatChannel",
        ChatChannel.create({ chatable_type: "DirectMessage" })
      );
      this.currentUser.set("needs_dm_retention_reminder", false);
      this.siteSettings.chat_dm_retention_days = 100;

      await render(
        hbs`<ChatRetentionReminder @chatChannel={{this.chatChannel}} />`
      );

      assert.false(exists(".chat-retention-reminder"));
    });
  }
);

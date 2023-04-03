import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module(
  "Discourse Chat | Component | chat-retention-reminder",
  function (hooks) {
    setupRenderingTest(hooks);

    test("display retention info", async function (assert) {
      this.channel = ChatChannel.create({ chatable_type: "Category" });
      this.currentUser.set("needs_channel_retention_reminder", true);

      await render(hbs`<ChatRetentionReminder @channel={{this.channel}} />`);

      assert.dom(".chat-retention-reminder").includesText(
        I18n.t("chat.retention_reminders.public", {
          count: this.siteSettings.chat_channel_retention_days,
        })
      );
    });
  }
);

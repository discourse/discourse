import Bookmark from "discourse/models/bookmark";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { module } from "qunit";
import User from "discourse/models/user";

module("Discourse Chat | Component | chat-message-info", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("chat_webhook_event", {
    template: hbs`{{chat-message-info message=message}}`,

    beforeEach() {
      this.set("message", { chat_webhook_event: { username: "discobot" } });
    },

    async test(assert) {
      assert.equal(
        query(".chat-message-info__username").innerText.trim(),
        this.message.chat_webhook_event.username
      );
      assert.equal(
        query(".chat-message-info__bot-indicator").textContent.trim(),
        I18n.t("chat.bot")
      );
    },
  });

  componentTest("user", {
    template: hbs`{{chat-message-info message=message}}`,

    beforeEach() {
      this.set("message", { user: { username: "discobot" } });
    },

    async test(assert) {
      assert.equal(
        query(".chat-message-info__username").innerText.trim(),
        this.message.user.username
      );
    },
  });

  componentTest("date", {
    template: hbs`{{chat-message-info message=message}}`,

    beforeEach() {
      this.set("message", {
        user: { username: "discobot" },
        created_at: moment(),
      });
    },

    async test(assert) {
      assert.ok(exists(".chat-message-info__date"));
    },
  });

  componentTest("bookmark (with reminder)", {
    template: hbs`{{chat-message-info message=message}}`,

    beforeEach() {
      this.set("message", {
        user: { username: "discobot" },
        bookmark: Bookmark.create({
          reminder_at: moment(),
          name: "some name",
        }),
      });
    },

    async test(assert) {
      assert.ok(
        exists(".chat-message-info__bookmark .d-icon-discourse-bookmark-clock")
      );
    },
  });

  componentTest("bookmark (no reminder)", {
    template: hbs`{{chat-message-info message=message}}`,

    beforeEach() {
      this.set("message", {
        user: { username: "discobot" },
        bookmark: Bookmark.create({
          name: "some name",
        }),
      });
    },

    async test(assert) {
      assert.ok(exists(".chat-message-info__bookmark .d-icon-bookmark"));
    },
  });

  componentTest("user status", {
    template: hbs`{{chat-message-info message=message}}`,

    beforeEach() {
      const status = { description: "off to dentist", emoji: "tooth" };
      this.set("message", { user: User.create({ status }) });
    },

    async test(assert) {
      assert.ok(exists(".chat-message-info__status .user-status-message"));
    },
  });

  componentTest("reviewable", {
    template: hbs`{{chat-message-info message=message}}`,

    beforeEach() {
      this.set("message", {
        user: { username: "discobot" },
        user_flag_status: 0,
      });
    },

    async test(assert) {
      assert.equal(
        query(".chat-message-info__flag > .svg-icon-title").title,
        I18n.t("chat.you_flagged")
      );

      this.set("message", {
        user: { username: "discobot" },
        reviewable_id: 1,
      });

      assert.equal(
        query(".chat-message-info__flag a .svg-icon-title").title,
        I18n.t("chat.flagged")
      );
    },
  });
});

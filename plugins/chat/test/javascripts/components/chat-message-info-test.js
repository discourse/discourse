import Bookmark from "discourse/models/bookmark";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { module, test } from "qunit";
import User from "discourse/models/user";
import { render } from "@ember/test-helpers";

module("Discourse Chat | Component | chat-message-info", function (hooks) {
  setupRenderingTest(hooks);

  test("chat_webhook_event", async function (assert) {
    this.set("message", { chat_webhook_event: { username: "discobot" } });

    await render(hbs`<ChatMessageInfo @message={{this.message}} />`);

    assert.strictEqual(
      query(".chat-message-info__username").innerText.trim(),
      this.message.chat_webhook_event.username
    );
    assert.strictEqual(
      query(".chat-message-info__bot-indicator").textContent.trim(),
      I18n.t("chat.bot")
    );
  });

  test("user", async function (assert) {
    this.set("message", { user: { username: "discobot" } });

    await render(hbs`<ChatMessageInfo @message={{this.message}} />`);

    assert.strictEqual(
      query(".chat-message-info__username").innerText.trim(),
      this.message.user.username
    );
  });

  test("date", async function (assert) {
    this.set("message", {
      user: { username: "discobot" },
      created_at: moment(),
    });

    await render(hbs`<ChatMessageInfo @message={{this.message}} />`);

    assert.true(exists(".chat-message-info__date"));
  });

  test("bookmark (with reminder)", async function (assert) {
    this.set("message", {
      user: { username: "discobot" },
      bookmark: Bookmark.create({
        reminder_at: moment(),
        name: "some name",
      }),
    });

    await render(hbs`<ChatMessageInfo @message={{this.message}} />`);

    assert.true(
      exists(".chat-message-info__bookmark .d-icon-discourse-bookmark-clock")
    );
  });

  test("bookmark (no reminder)", async function (assert) {
    this.set("message", {
      user: { username: "discobot" },
      bookmark: Bookmark.create({
        name: "some name",
      }),
    });

    await render(hbs`<ChatMessageInfo @message={{this.message}} />`);

    assert.true(exists(".chat-message-info__bookmark .d-icon-bookmark"));
  });

  test("user status", async function (assert) {
    const status = { description: "off to dentist", emoji: "tooth" };
    this.set("message", { user: User.create({ status }) });

    await render(hbs`<ChatMessageInfo @message={{this.message}} />`);

    assert.true(exists(".chat-message-info__status .user-status-message"));
  });

  test("reviewable", async function (assert) {
    this.set("message", {
      user: { username: "discobot" },
      user_flag_status: 0,
    });

    await render(hbs`<ChatMessageInfo @message={{this.message}} />`);

    assert.strictEqual(
      query(".chat-message-info__flag > .svg-icon-title").title,
      I18n.t("chat.you_flagged")
    );

    this.set("message", {
      user: { username: "discobot" },
      reviewable_id: 1,
    });

    assert.strictEqual(
      query(".chat-message-info__flag a .svg-icon-title").title,
      I18n.t("chat.flagged")
    );
  });
});

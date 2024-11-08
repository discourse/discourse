import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import Bookmark from "discourse/models/bookmark";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Discourse Chat | Component | chat-message-info", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`
    <Chat::Message::Info @message={{this.message}} @show={{true}} />
  `;

  test("chat_webhook_event", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      chat_webhook_event: { username: "discobot" },
    });

    await render(template);

    assert
      .dom(".chat-message-info__username")
      .hasText(this.message.chatWebhookEvent.username);
    assert.strictEqual(
      query(".chat-message-info__bot-indicator").textContent.trim(),
      I18n.t("chat.bot")
    );
  });

  test("user", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      user: { username: "discobot" },
    });

    await render(template);

    assert
      .dom(".chat-message-info__username")
      .hasText(this.message.user.username);
  });

  test("date", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      user: { username: "discobot" },
      created_at: moment(),
    });

    await render(template);

    assert.dom(".chat-message-info__date").exists();
  });

  test("bookmark (with reminder)", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      user: { username: "discobot" },
      bookmark: Bookmark.create({
        reminder_at: moment(),
        name: "some name",
      }),
    });

    await render(template);

    assert
      .dom(".chat-message-info__bookmark .d-icon-discourse-bookmark-clock")
      .exists();
  });

  test("bookmark (no reminder)", async function (assert) {
    this.message = ChatMessage.create(
      new ChatFabricators(getOwner(this)).channel(),
      {
        user: { username: "discobot" },
        bookmark: Bookmark.create({
          name: "some name",
        }),
      }
    );

    await render(template);

    assert.dom(".chat-message-info__bookmark .d-icon-bookmark").exists();
  });

  test("user status", async function (assert) {
    const status = { description: "off to dentist", emoji: "tooth" };
    this.message = new ChatFabricators(getOwner(this)).message({
      user: { status },
    });

    await render(template);

    assert.dom(".chat-message-info__status .user-status-message").exists();
  });

  test("flag status", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      user: { username: "discobot" },
      user_flag_status: 0,
    });

    await render(template);

    assert
      .dom(".chat-message-info__flag > .svg-icon-title")
      .hasAttribute("title", I18n.t("chat.you_flagged"));
  });

  test("reviewable", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      user: { username: "discobot" },
      user_flag_status: 0,
    });

    await render(template);

    assert
      .dom(".chat-message-info__flag > .svg-icon-title")
      .hasAttribute("title", I18n.t("chat.you_flagged"));
  });

  test("with username classes", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      user: {
        username: "discobot",
        admin: true,
        moderator: true,
        new_user: true,
        primary_group_name: "foo",
      },
    });

    await render(template);

    assert.dom(".chat-message-info__username.is-staff").exists();
    assert.dom(".chat-message-info__username.is-admin").exists();
    assert.dom(".chat-message-info__username.is-moderator").exists();
    assert.dom(".chat-message-info__username.is-new-user").exists();
    assert.dom(".chat-message-info__username.group--foo").exists();
  });

  test("without username classes", async function (assert) {
    this.message = new ChatFabricators(getOwner(this)).message({
      user: { username: "discobot" },
    });

    await render(template);

    assert.dom(".chat-message-info__username.is-staff").doesNotExist();
    assert.dom(".chat-message-info__username.is-admin").doesNotExist();
    assert.dom(".chat-message-info__username.is-moderator").doesNotExist();
    assert.dom(".chat-message-info__username.is-new-user").doesNotExist();
    assert.dom(".chat-message-info__username.group--foo").doesNotExist();
  });
});

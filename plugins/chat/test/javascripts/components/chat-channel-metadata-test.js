import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-channel-metadata", function (hooks) {
  setupRenderingTest(hooks);

  test("displays last message created at", async function (assert) {
    let lastMessageSentAt = moment().subtract(1, "day").format();
    this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();
    this.channel.lastMessage = new ChatFabricators(getOwner(this)).message({
      channel: this.channel,
      created_at: lastMessageSentAt,
    });

    await render(hbs`<ChatChannelMetadata @channel={{this.channel}} />`);

    assert.dom(".chat-channel__metadata-date").hasText("Yesterday");

    lastMessageSentAt = moment();
    this.channel.lastMessage.createdAt = lastMessageSentAt;
    await render(hbs`<ChatChannelMetadata @channel={{this.channel}} />`);

    assert
      .dom(".chat-channel__metadata-date")
      .hasText(lastMessageSentAt.format("LT"));
  });

  test("unreadIndicator", async function (assert) {
    this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();
    this.channel.tracking.unreadCount = 1;

    this.unreadIndicator = true;
    await render(
      hbs`<ChatChannelMetadata @channel={{this.channel}} @unreadIndicator={{this.unreadIndicator}}/>`
    );

    assert.true(exists(".chat-channel-unread-indicator"));

    this.unreadIndicator = false;
    await render(
      hbs`<ChatChannelMetadata @channel={{this.channel}} @unreadIndicator={{this.unreadIndicator}}/>`
    );

    assert.false(exists(".chat-channel-unread-indicator"));
  });
});

import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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
});

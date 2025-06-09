import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatChannelMetadata from "discourse/plugins/chat/discourse/components/chat-channel-metadata";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-channel-metadata", function (hooks) {
  setupRenderingTest(hooks);

  test("displays created at placeholder for empty chat", async function (assert) {
    const self = this;
    this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();
    this.channel.lastMessage = new ChatFabricators(getOwner(this)).message({
      channel: this.channel,
      created_at: Date.now(),
      id: null,
    });

    await render(
      <template><ChatChannelMetadata @channel={{self.channel}} /></template>
    );

    assert.dom(".chat-channel__metadata-date").hasText("–");
  });

  test("displays last message created at", async function (assert) {
    const self = this;

    let lastMessageSentAt = moment().subtract(1, "day").format();
    this.channel = new ChatFabricators(getOwner(this)).directMessageChannel();
    this.channel.lastMessage = new ChatFabricators(getOwner(this)).message({
      channel: this.channel,
      created_at: lastMessageSentAt,
    });

    await render(
      <template><ChatChannelMetadata @channel={{self.channel}} /></template>
    );

    assert.dom(".chat-channel__metadata-date").hasText("Yesterday");

    lastMessageSentAt = moment();
    this.channel.lastMessage.createdAt = lastMessageSentAt;
    await render(
      <template><ChatChannelMetadata @channel={{self.channel}} /></template>
    );

    assert
      .dom(".chat-channel__metadata-date")
      .hasText(lastMessageSentAt.format("LT"));
  });
});

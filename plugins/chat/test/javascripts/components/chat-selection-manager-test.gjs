import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatSelectionManager from "discourse/plugins/chat/discourse/components/chat/selection-manager";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | <Chat::SelectionManager />", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.channel = new ChatFabricators(getOwner(this)).channel();
    this.message = new ChatFabricators(getOwner(this)).message({
      channel: this.channel,
    });
    this.channel.messagesManager.addMessages([this.message]);

    this.pane = getOwner(this).lookup("service:chat-channel-pane");
    this.pane.selectingMessages = true;
  });

  test("renders its actions when the channel is not the active channel", async function (assert) {
    const chat = getOwner(this).lookup("service:chat");
    assert.strictEqual(chat.activeChannel, null, "no active channel is set");

    await render(
      <template>
        <ChatSelectionManager
          @channel={{this.channel}}
          @pane={{this.pane}}
          @messagesManager={{this.channel.messagesManager}}
        />
      </template>
    );

    assert.dom("#chat-quote-btn").exists();
    assert.dom("#chat-copy-btn").exists();
    assert.dom("#chat-delete-btn").exists();
    assert.dom("#chat-cancel-selection-btn").exists();
  });

  test("actions are disabled until messages are selected", async function (assert) {
    await render(
      <template>
        <ChatSelectionManager
          @channel={{this.channel}}
          @pane={{this.pane}}
          @messagesManager={{this.channel.messagesManager}}
        />
      </template>
    );

    assert.dom("#chat-quote-btn").isDisabled();

    this.message.selected = true;
    await settled();

    assert.dom("#chat-quote-btn").isEnabled();
  });

  test("cancelling clears the selection", async function (assert) {
    this.message.selected = true;

    await render(
      <template>
        <ChatSelectionManager
          @channel={{this.channel}}
          @pane={{this.pane}}
          @messagesManager={{this.channel.messagesManager}}
        />
      </template>
    );

    await click("#chat-cancel-selection-btn");

    assert.false(this.message.selected, "the message is deselected");
    assert.false(this.pane.selectingMessages, "selection mode is exited");
  });
});

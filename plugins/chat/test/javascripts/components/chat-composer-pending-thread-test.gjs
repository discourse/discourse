import { trackedObject } from "@ember/reactive/collections";
import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatComposerPendingThread from "discourse/plugins/chat/discourse/components/chat/composer/pending-thread";
import {
  clearChatComposerButtons,
  registerChatComposerButton,
} from "discourse/plugins/chat/discourse/lib/chat-composer-buttons";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

module("Component | Chat | Composer | PendingThread", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.channel = new ChatFabricators(this.owner).channel();
    this.draft = ChatMessage.createDraftMessage(this.channel, {
      user: this.currentUser,
    });
    this.channel.resetDraft(this.currentUser);
    this.pane = trackedObject({ sending: false });
    this.onSendMessage = () => {};
  });

  hooks.afterEach(function () {
    clearChatComposerButtons();
  });

  test("routes picked media through the host instead of posting to the channel", async function (assert) {
    registerChatComposerButton({
      id: "pending-media",
      icon: "image",
      label: "chat.upload",
      position: "dropdown",
      action() {
        return this.sendPickedGif("https://example.com/image.gif");
      },
    });
    let submitted;
    this.onSendMessage = (draft) => {
      submitted = draft;
    };
    await render(
      <template>
        <ChatComposerPendingThread
          @channel={{this.channel}}
          @draft={{this.draft}}
          @onSendMessage={{this.onSendMessage}}
          @pane={{this.pane}}
        />
      </template>
    );
    await fillIn(".chat-composer__input", "my unfinished text");
    await click(".chat-composer-dropdown__trigger-btn");
    await click(".chat-composer-dropdown__action-btn.pending-media");
    assert.strictEqual(
      submitted.message,
      "https://example.com/image.gif",
      "the host receives the picked image"
    );
    assert.strictEqual(
      submitted.thread,
      undefined,
      "the image does not get a synthetic thread ID"
    );
    assert
      .dom(".chat-composer__input")
      .hasValue(
        "my unfinished text",
        "the pending text is retained independently"
      );
  });

  test("uses the native editor without a thread or typing subscription", async function (assert) {
    this.onSendMessage = (draft) => {
      assert.strictEqual(
        draft.message,
        "hello :wave:",
        "the complete draft is submitted"
      );
      assert.strictEqual(
        draft.thread,
        undefined,
        "no synthetic thread is attached"
      );
    };

    await render(
      <template>
        <ChatComposerPendingThread
          @channel={{this.channel}}
          @draft={{this.draft}}
          @onSendMessage={{this.onSendMessage}}
          @pane={{this.pane}}
          @placeholder="Message the room"
        />
      </template>
    );
    assert
      .dom(".chat-composer__input")
      .hasAttribute(
        "placeholder",
        "Message the room",
        "the native editor is rendered"
      );
    assert
      .dom(".chat-replying-indicator-container")
      .doesNotExist("no thread typing subscription is mounted");
    await fillIn(".chat-composer__input", "hello :wave:");
    await triggerKeyEvent(".chat-composer__input", "keydown", "Enter");
    assert.strictEqual(
      this.channel.draft?.message,
      "",
      "the channel draft is independent"
    );
  });

  test("preserves a pending draft when sending fails", async function (assert) {
    this.onSendMessage = () => {};
    await render(
      <template>
        <ChatComposerPendingThread
          @channel={{this.channel}}
          @draft={{this.draft}}
          @onSendMessage={{this.onSendMessage}}
          @pane={{this.pane}}
        />
      </template>
    );
    await fillIn(".chat-composer__input", "keep this draft");
    await triggerKeyEvent(".chat-composer__input", "keydown", "Enter");
    assert
      .dom(".chat-composer__input")
      .hasValue(
        "keep this draft",
        "the host controls clearing after acceptance"
      );
    await fillIn(".chat-composer__input", "");
    await triggerKeyEvent(".chat-composer__input", "keydown", "ArrowUp");
    assert
      .dom(".chat-composer__input")
      .hasValue("", "channel history is not edited in a pending thread");
  });
});

import { tracked } from "@glimmer/tracking";
import {
  click,
  fillIn,
  find,
  render,
  settled,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  createFile,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";
import LiveChatPanel from "discourse/plugins/live/discourse/components/live/chat-panel";

module("Live | Integration | Component | Live | ChatPanel", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.siteSettings.chat_allow_uploads = true;
    this.siteSettings.authorized_extensions = "png";
    this.room = { id: 1 };
    const fabricators = new ChatFabricators(this.owner);
    this.channel = fabricators.channel({ id: 123 });
    this.channel.currentUserMembership = UserChatChannelMembership.create({
      following: true,
    });
    this.owner.lookup("service:chat-channels-manager").store(this.channel);
    this.thread = fabricators.thread({
      id: 456,
      channel: this.channel,
      title: "Room conversation",
    });
    this.channel.threadsManager.add(this.channel, this.thread);
    this.state = { channel_id: this.channel.id, thread_id: null };
    pretender.post("/live/rooms/1/chat_session", () => response(this.state));
    pretender.get("/live/rooms/1/chat_session", () => response(this.state));
    pretender.get("/chat/api/channels/123/threads/456/messages", () =>
      response({
        messages: [],
        meta: { can_load_more_past: false, can_load_more_future: false },
      })
    );
    pretender.post("/chat/api/channels/123/threads/456/drafts", () =>
      response({ success: "OK" })
    );
    pretender.post("/chat/api/channels/123/drafts", () =>
      response({ success: "OK" })
    );
  });

  test("keeps room drafts when the panel is closed and reopened", async function (assert) {
    const visible = tracked(true);
    await render(
      <template>
        {{#if visible.value}}<LiveChatPanel @room={{this.room}} />{{/if}}
      </template>
    );
    await fillIn(".live-chat textarea", "unfinished room message");
    visible.value = false;
    await settled();
    visible.value = true;
    await settled();
    assert
      .dom(".live-chat textarea")
      .hasValue(
        "unfinished room message",
        "the pending draft survives reopening"
      );
    assert
      .dom(".live-chat .chat-thread")
      .doesNotExist("opening creates no thread");
  });

  test("transfers the draft and caret when another participant starts the thread", async function (assert) {
    await render(<template><LiveChatPanel @room={{this.room}} /></template>);
    await fillIn(".live-chat textarea", "I was composing this");
    find(".live-chat textarea").focus();
    find(".live-chat textarea").setSelectionRange(4, 7);
    this.state = { channel_id: 123, thread_id: 456 };
    await publishToMessageBus("/live/rooms/1/chat", { type: "updated" });
    await settled();
    assert
      .dom(".live-chat .chat-thread")
      .exists("the normal thread replaces the empty state");
    assert
      .dom(".live-chat textarea")
      .hasValue("I was composing this", "the pending text is retained");
    assert.strictEqual(
      find(".live-chat textarea").selectionStart,
      4,
      "the selection is retained"
    );
    assert.strictEqual(
      find(".live-chat textarea").selectionEnd,
      7,
      "the selection end is retained"
    );
  });

  test("keeps the thread active across repeated session notifications", async function (assert) {
    this.state = { channel_id: 123, thread_id: 456 };
    await render(<template><LiveChatPanel @room={{this.room}} /></template>);
    await publishToMessageBus("/live/rooms/1/chat", { type: "updated" });
    assert.strictEqual(
      this.owner.lookup("service:chat").activeChannel.activeThread,
      this.thread,
      "a duplicate refresh preserves the current thread context"
    );
  });

  test("preserves an existing thread draft when the room draft is transferred", async function (assert) {
    const saved = ChatMessage.createDraftMessage(this.channel, {
      user: this.currentUser,
      message: "saved in Chat",
    });
    this.owner
      .lookup("service:chat-drafts-manager")
      .add(saved, 123, 456, false);
    await render(<template><LiveChatPanel @room={{this.room}} /></template>);
    await fillIn(".live-chat textarea", "typed in the room");
    this.state = { channel_id: 123, thread_id: 456 };
    await publishToMessageBus("/live/rooms/1/chat", { type: "updated" });
    assert
      .dom(".live-chat textarea")
      .hasValue(
        "saved in Chat\n\ntyped in the room",
        "both drafts survive the handoff"
      );
  });

  test("retains rejected text and completed attachments", async function (assert) {
    const draft = this.owner
      .lookup("service:live-chat-drafts")
      .get(1, this.channel);
    draft.uploads = [
      {
        id: 202,
        original_filename: "photo.png",
        extension: "png",
        url: "/images/avatar.png",
      },
    ];
    pretender.post("/live/rooms/1/chat_message", () =>
      response(422, { errors: ["Please try again"] })
    );
    await render(<template><LiveChatPanel @room={{this.room}} /></template>);
    await fillIn(".live-chat textarea", "keep my attachment");
    await click(".live-chat .chat-composer-button.-send");
    assert
      .dom(".live-chat textarea")
      .hasValue("keep my attachment", "the rejected text remains editable");
    assert
      .dom(".live-chat .chat-composer-upload")
      .exists("the completed upload is retained");
    assert
      .dom(".live-chat .chat-thread")
      .doesNotExist("rejection does not create a local thread");
  });

  test("waits for uploads before switching to a remotely created thread", async function (assert) {
    let uploadRequest;
    pretender.post(
      "/uploads.json",
      (request) => {
        uploadRequest = request;
        return response({
          id: 202,
          original_filename: "avatar.png",
          extension: "png",
          url: "/images/avatar.png",
          short_url: "upload://test.png",
          width: 100,
          height: 100,
        });
      },
      true
    );
    await render(<template><LiveChatPanel @room={{this.room}} /></template>);
    await fillIn(".live-chat textarea", "with a photo");
    this.owner
      .lookup("service:app-events")
      .trigger(
        "upload-mixin:chat-composer-uploader:add-files",
        createFile("avatar.png")
      );
    await waitFor(".chat-composer-upload");
    this.state = { channel_id: 123, thread_id: 456 };
    let refreshed = false;
    pretender.get("/live/rooms/1/chat_session", () => {
      refreshed = true;
      return response(this.state);
    });
    const refresh = publishToMessageBus("/live/rooms/1/chat", {
      type: "updated",
    });
    await waitUntil(() => refreshed && uploadRequest);
    assert
      .dom(".live-chat .chat-thread")
      .doesNotExist("the uploader stays mounted");
    pretender.resolve(uploadRequest);
    await refresh;
    assert
      .dom(".live-chat .chat-thread")
      .exists("the thread is activated after uploading");
    assert
      .dom(".live-chat textarea")
      .hasValue("with a photo", "the text survives the transition");
    assert
      .dom(".live-chat .chat-composer-upload")
      .exists("the completed attachment is retained");
  });

  test("retries loading after acceptance without submitting the first message again", async function (assert) {
    let sends = 0;
    // Force a network fetch instead of using the existing cached thread.
    this.channel.threadsManager.remove(this.thread);
    let failLoading = true;
    pretender.get("/chat/api/channels/123/threads/456", () =>
      failLoading
        ? response(500, {})
        : response({ thread: { id: 456, title: "Room conversation" } })
    );
    pretender.post("/live/rooms/1/chat_message", () => {
      sends++;
      return response({ channel_id: 123, thread_id: 456, message_id: 789 });
    });
    await render(<template><LiveChatPanel @room={{this.room}} /></template>);
    await fillIn(".live-chat textarea", "first message");
    await click(".live-chat .chat-composer-button.-send");
    assert
      .dom(".live-chat textarea")
      .isDisabled("accepted content cannot be resent during a load failure");
    failLoading = false;
    await click(".live-chat__pending > .btn");
    assert
      .dom(".live-chat .chat-thread")
      .exists("loading can be retried independently");
    assert.strictEqual(sends, 1, "the accepted message is posted once");
  });
});

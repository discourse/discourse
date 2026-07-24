import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  clearPresenceCallbacks,
  processBrowserAttentionChange,
  setTestPresence,
} from "discourse/lib/user-presence";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";
import ChatThread from "discourse/plugins/chat/discourse/components/chat-thread";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

function setScrollerHeight(scroller, { clientHeight, scrollHeight }) {
  Object.defineProperty(scroller, "clientHeight", {
    configurable: true,
    value: clientHeight,
  });
  Object.defineProperty(scroller, "scrollHeight", {
    configurable: true,
    value: scrollHeight,
  });
}

function stubDocumentAttention({
  hasFocus = true,
  visibilityState = "visible",
}) {
  sinon.stub(document, "hasFocus").returns(hasFocus);
  sinon.stub(document, "visibilityState").value(visibilityState);
}

function publishChannelMessage(channelId, messageId, user) {
  publishToMessageBus(`/chat/${channelId}`, {
    type: "sent",
    chat_message: {
      id: messageId,
      message: `hello ${messageId}`,
      cooked: `<p>hello ${messageId}</p>`,
      excerpt: `hello ${messageId}`,
      created_at: "2025-01-01T00:00:00.000Z",
      user,
    },
  });
}

function setChannelMembership(channel, lastReadMessageId = 1) {
  channel.currentUserMembership.following = true;
  channel.currentUserMembership.lastReadMessageId = lastReadMessageId;
}

function readRequests() {
  return pretender.handledRequests.filter(
    ({ method, url }) =>
      method === "PUT" && url.startsWith("/chat/api/channels/1/read")
  );
}

module("Unit | Components | presence gating", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new ChatFabricators(getOwner(this));
    setTestPresence(false);

    pretender.get(`/chat/api/channels/1/messages`, () =>
      response({
        messages: [],
        meta: {
          can_delete_self: true,
          can_load_more_future: false,
          can_load_more_past: false,
        },
      })
    );
    pretender.get(`/chat/api/me/channels`, () =>
      response({
        direct_message_channels: [],
        public_channels: [],
      })
    );
    pretender.get(`/chat/api/channels/1/threads/1/messages`, () =>
      response({
        messages: [],
        meta: {
          can_load_more_future: false,
          can_load_more_past: false,
        },
      })
    );
    pretender.put(`/chat/api/channels/1/read`, () =>
      response({ success: true })
    );
    pretender.post(`/chat/api/channels/1/drafts`, () =>
      response({ success: true })
    );
  });

  hooks.afterEach(function () {
    setTestPresence(true);
    clearPresenceCallbacks();
    sinon.restore();
  });

  test("does not show arrow when user not present but pane cannot scroll", async function (assert) {
    const channel = this.fabricators.channel({ id: 1 });

    const readUpdateStub = sinon.stub(
      ChatChannel.prototype,
      "debouncedUpdateLastReadMessage"
    );

    this.channel = channel;
    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    setScrollerHeight(this.element.querySelector(".chat-messages-scroller"), {
      clientHeight: 500,
      scrollHeight: 500,
    });

    const addMessagesStub = sinon.stub(channel.messagesManager, "addMessages");
    readUpdateStub.resetHistory();

    publishToMessageBus(`/chat/1`, {
      type: "sent",
      chat_message: {
        id: 999,
        message: "hello",
        cooked: "<p>hello</p>",
        excerpt: "hello",
        created_at: "2025-01-01T00:00:00.000Z",
        user: { id: 1, username: "eviltrout" },
      },
    });
    await settled();

    assert.true(addMessagesStub.calledOnce, "appends messages");
    assert.false(readUpdateStub.called, "does not schedule read update");
    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .doesNotExist("does not show scroll-to-bottom arrow");
  });

  test("shows arrow when user not present and pane can scroll", async function (assert) {
    const channel = this.fabricators.channel({ id: 1 });

    this.channel = channel;
    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    setScrollerHeight(this.element.querySelector(".chat-messages-scroller"), {
      clientHeight: 100,
      scrollHeight: 500,
    });

    publishToMessageBus(`/chat/1`, {
      type: "sent",
      chat_message: {
        id: 999,
        message: "hello",
        cooked: "<p>hello</p>",
        excerpt: "hello",
        created_at: "2025-01-01T00:00:00.000Z",
        user: { id: 1, username: "eviltrout" },
      },
    });
    await settled();

    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .exists("shows scroll-to-bottom arrow");
  });

  test("pending manager tracks messages across contexts", async function (assert) {
    const channel = this.fabricators.channel({ id: 1 });

    this.channel = channel;
    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    const pendingManager = getOwner(this).lookup(
      "service:chat-pane-pending-manager"
    );
    assert.strictEqual(
      pendingManager.totalPendingMessageCount,
      0,
      "starts at zero"
    );

    publishToMessageBus(`/chat/1`, {
      type: "sent",
      chat_message: {
        id: 999,
        message: "hello",
        cooked: "<p>hello</p>",
        excerpt: "hello",
        created_at: "2025-01-01T00:00:00.000Z",
        user: { id: 1, username: "eviltrout" },
      },
    });
    await settled();

    assert.strictEqual(
      pendingManager.totalPendingMessageCount,
      1,
      "increments on new message"
    );
  });

  test("clears pending state when scrolling to bottom", async function (assert) {
    const channel = this.fabricators.channel({ id: 1 });

    this.channel = channel;
    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    setScrollerHeight(this.element.querySelector(".chat-messages-scroller"), {
      clientHeight: 100,
      scrollHeight: 500,
    });

    const pendingManager = getOwner(this).lookup(
      "service:chat-pane-pending-manager"
    );

    publishToMessageBus(`/chat/1`, {
      type: "sent",
      chat_message: {
        id: 999,
        message: "hello",
        cooked: "<p>hello</p>",
        excerpt: "hello",
        created_at: "2025-01-01T00:00:00.000Z",
        user: { id: 1, username: "eviltrout" },
      },
    });
    await settled();

    assert.strictEqual(
      pendingManager.totalPendingMessageCount,
      1,
      "has pending message"
    );

    await click(".chat-scroll-to-bottom__button");

    assert.strictEqual(
      pendingManager.totalPendingMessageCount,
      0,
      "clears pending on scroll to bottom"
    );
    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .doesNotExist("hides arrow after scroll");
  });

  test("pending count contributes to document title", async function (assert) {
    const channel = this.fabricators.channel({ id: 1 });

    this.channel = channel;
    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    const chatService = getOwner(this).lookup("service:chat");
    const initialCount = chatService.getDocumentTitleCount();

    publishToMessageBus(`/chat/1`, {
      type: "sent",
      chat_message: {
        id: 999,
        message: "hello",
        cooked: "<p>hello</p>",
        excerpt: "hello",
        created_at: "2025-01-01T00:00:00.000Z",
        user: { id: 1, username: "eviltrout" },
      },
    });
    await settled();

    assert.strictEqual(
      chatService.getDocumentTitleCount(),
      initialCount + 1,
      "pending message increments document title count"
    );
  });

  test("unfocused visible window at bottom follows without marking read until focus", async function (assert) {
    setTestPresence(true);
    stubDocumentAttention({ hasFocus: false, visibilityState: "visible" });

    const channel = this.fabricators.channel({ id: 1 });
    setChannelMembership(channel);
    const otherUser = { id: 9999, username: "other" };

    this.channel = channel;
    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    pretender.handledRequests.length = 0;

    publishChannelMessage(1, 999, otherUser);
    publishChannelMessage(1, 1000, otherUser);
    publishChannelMessage(1, 1001, otherUser);
    await settled();

    assert.strictEqual(
      channel.messagesManager.messages.length,
      3,
      "appends messages while passively following"
    );
    assert.strictEqual(
      readRequests().length,
      0,
      "does not schedule read update"
    );
    assert.strictEqual(
      channel.currentUserMembership.lastReadMessageId,
      1,
      "does not advance local durable read state while unfocused"
    );
    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .doesNotExist("does not show the scroll arrow while live-following");

    document.hasFocus.returns(true);
    processBrowserAttentionChange();
    await settled();

    assert.strictEqual(
      readRequests().length,
      1,
      "marks read when focus returns"
    );
    assert.strictEqual(
      channel.currentUserMembership.lastReadMessageId,
      1001,
      "advances local durable read state when focus returns"
    );
  });

  test("hidden tab enqueues messages without marking read", async function (assert) {
    setTestPresence(true);
    stubDocumentAttention({ hasFocus: false, visibilityState: "hidden" });

    const channel = this.fabricators.channel({ id: 1 });
    setChannelMembership(channel);
    const otherUser = { id: 9999, username: "other" };

    const readUpdateStub = sinon.stub(
      ChatChannel.prototype,
      "debouncedUpdateLastReadMessage"
    );

    this.channel = channel;
    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    setScrollerHeight(this.element.querySelector(".chat-messages-scroller"), {
      clientHeight: 100,
      scrollHeight: 500,
    });
    readUpdateStub.resetHistory();

    publishChannelMessage(1, 999, otherUser);
    await settled();

    assert.false(readUpdateStub.called, "does not schedule read update");
    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .exists("shows jump affordance for hidden-tab messages");
  });

  test("own messages still follow while unfocused", async function (assert) {
    setTestPresence(true);
    stubDocumentAttention({ hasFocus: false, visibilityState: "visible" });

    const channel = this.fabricators.channel({ id: 1 });

    this.channel = channel;
    await render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    publishChannelMessage(1, 999, {
      id: this.currentUser.id,
      username: this.currentUser.username,
    });
    await settled();

    assert.strictEqual(
      channel.messagesManager.messages.length,
      1,
      "appends the current user's message"
    );
    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .doesNotExist("does not show the scroll arrow for own live messages");
  });

  test("thread enqueues messages when user not present", async function (assert) {
    const thread = this.fabricators.thread({
      id: 1,
      channel: this.fabricators.channel({ id: 1 }),
    });

    const readUpdateStub = sinon.stub(
      ChatThread.prototype,
      "debouncedUpdateLastReadMessage"
    );

    this.thread = thread;
    await render(<template><ChatThread @thread={{this.thread}} /></template>);

    setScrollerHeight(this.element.querySelector(".chat-messages-scroller"), {
      clientHeight: 100,
      scrollHeight: 500,
    });

    const addMessagesStub = sinon.stub(thread.messagesManager, "addMessages");
    readUpdateStub.resetHistory();

    publishToMessageBus(`/chat/1/thread/1`, {
      type: "sent",
      chat_message: {
        id: 1001,
        message: "thread hello",
        cooked: "<p>thread hello</p>",
        excerpt: "thread hello",
        created_at: "2025-01-01T00:00:00.000Z",
        user: { id: 1, username: "eviltrout" },
      },
    });
    await settled();

    assert.true(addMessagesStub.calledOnce, "appends messages");
    assert.false(readUpdateStub.called, "does not schedule read update");
    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .exists("shows scroll-to-bottom arrow");
  });
});

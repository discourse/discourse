import MockPresenceChannel from "../../helpers/mock-presence-channel";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import fabricators from "../../helpers/fabricators";
import { directMessageChannels } from "discourse/plugins/chat/chat-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import sinon from "sinon";
import pretender from "discourse/tests/helpers/create-pretender";
import { settled } from "@ember/test-helpers";

acceptance("Discourse Chat | Unit | Service | chat", function (needs) {
  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "chatService", {
      get: () => this.container.lookup("service:chat"),
    });
    Object.defineProperty(this, "currentUser", {
      get: () => this.container.lookup("service:current-user"),
    });
  });

  needs.user({ ignored_users: [] });

  needs.pretender((server, helper) => {
    server.get("/chat/chat_channels.json", () => {
      return helper.response({
        public_channels: [
          {
            id: 1,
            title: "something",
            chatable_type: "Category",
            last_message_sent_at: "2021-11-08T21:26:05.710Z",
            current_user_membership: {
              unread_count: 2,
              last_read_message_id: 123,
              unread_mentions: 0,
              muted: false,
            },
            message_bus_last_ids: {
              new_mentions: 0,
              new_messages: 0,
            },
          },
        ],
        direct_message_channels: [],
        message_bus_last_ids: {
          channel_metadata: 0,
          channel_edits: 0,
          channel_status: 0,
          new_channel: 0,
          user_tracking_state: 0,
        },
      });
    });

    server.put("/chat/:chatChannelId/read/:messageId.json", () => {
      return helper.response({ success: "OK" });
    });
  });

  function setupMockPresenceChannel(chatService) {
    chatService.set(
      "presenceChannel",
      MockPresenceChannel.create({
        name: `/chat-reply/1`,
      })
    );
  }

  test("#markNetworkAsReliable", async function (assert) {
    setupMockPresenceChannel(this.chatService);

    this.chatService.markNetworkAsReliable();

    assert.strictEqual(this.chatService.isNetworkUnreliable, false);
  });

  test("#markNetworkAsUnreliable", async function (assert) {
    setupMockPresenceChannel(this.chatService);
    this.chatService.markNetworkAsUnreliable();

    assert.strictEqual(this.chatService.isNetworkUnreliable, true);

    await settled();

    assert.strictEqual(
      this.chatService.isNetworkUnreliable,
      false,
      "it resets state after a delay"
    );
  });

  test("#startTrackingChannel - sorts dm channels", async function (assert) {
    setupMockPresenceChannel(this.chatService);
    const fixtures = cloneJSON(directMessageChannels).mapBy("chat_channel");
    const channel1 = ChatChannel.create(fixtures[0]);
    const channel2 = ChatChannel.create(fixtures[1]);
    await this.chatService.startTrackingChannel(channel1);
    this.currentUser.set(
      `chat_channel_tracking_state.${channel1.id}.unread_count`,
      0
    );
    await this.chatService.startTrackingChannel(channel2);

    assert.strictEqual(
      this.chatService.directMessageChannels.firstObject.title,
      channel2.title
    );
  });

  test("#refreshTrackingState", async function (assert) {
    this.currentUser.set("chat_channel_tracking_state", {});

    await this.chatService.refreshTrackingState();

    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].unread_count,
      2
    );
  });

  test("attempts to track a non followed channel", async function (assert) {
    this.currentUser.set("chat_channel_tracking_state", {});
    const channel = fabricators.chatChannel();
    await this.chatService.startTrackingChannel(channel);

    assert.false(channel.current_user_membership.following);
    assert.notOk(
      this.currentUser.chat_channel_tracking_state[channel.id],
      "it doesn’t track it"
    );
  });

  test("new message", async function (assert) {
    setupMockPresenceChannel(this.chatService);
    await this.chatService.forceRefreshChannels();

    await publishToMessageBus("/chat/1/new-messages", {
      user_id: this.currentUser.id,
      username: this.currentUser.username,
      message_id: 124,
    });

    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].chat_message_id,
      124,
      "updates tracking state last message id to the message id sent by current user"
    );
    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].unread_count,
      2,
      "does not increment unread count"
    );
  });

  test("/chat/:channelId/new-messages - message from current user", async function (assert) {
    setupMockPresenceChannel(this.chatService);
    await this.chatService.forceRefreshChannels();

    await publishToMessageBus("/chat/1/new-messages", {
      user_id: this.currentUser.id,
      username: this.currentUser.username,
      message_id: 124,
    });

    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].chat_message_id,
      124,
      "updates tracking state last message id to the message id sent by current user"
    );
    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].unread_count,
      2,
      "does not increment unread count"
    );
  });

  test("/chat/:channelId/new-messages - message from user that current user is ignoring", async function (assert) {
    this.currentUser.set("ignored_users", ["johnny"]);
    setupMockPresenceChannel(this.chatService);
    await this.chatService.forceRefreshChannels();

    await publishToMessageBus("/chat/1/new-messages", {
      user_id: 2327,
      username: "johnny",
      message_id: 124,
    });

    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].chat_message_id,
      124,
      "updates tracking state last message id to the message id sent by johnny"
    );
    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].unread_count,
      2,
      "does not increment unread count"
    );
  });

  test("/chat/:channelId/new-messages - message from another user", async function (assert) {
    setupMockPresenceChannel(this.chatService);
    await this.chatService.forceRefreshChannels();

    await publishToMessageBus("/chat/1/new-messages", {
      user_id: 2327,
      username: "jane",
      message_id: 124,
    });

    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].chat_message_id,
      123,
      "does not update tracking state last message id to the message id sent by jane"
    );
    assert.equal(
      this.currentUser.chat_channel_tracking_state[1].unread_count,
      3,
      "does increment unread count"
    );
  });

  test("#updateLastReadMessage - updates and tracks the last read message", async function (assert) {
    this.currentUser.set("chat_channel_tracking_state", {});
    sinon.stub(document, "querySelectorAll").callsFake(function () {
      return [{ dataset: { id: 2 } }];
    });
    const activeChannel = fabricators.chatChannel({
      current_user_membership: { last_read_message_id: 1, following: true },
    });
    this.chatService.setActiveChannel(activeChannel);

    this.chatService.updateLastReadMessage();
    await settled();

    assert.equal(activeChannel.lastSendReadMessageId, 2);
  });

  test("#updateLastReadMessage - does nothing if the user doesn't follow the channel", async function (assert) {
    this.currentUser.set("chat_channel_tracking_state", {});
    this.chatService.setActiveChannel(
      fabricators.chatChannel({ current_user_membership: { following: false } })
    );
    sinon.stub(document, "querySelectorAll").callsFake(function () {
      return [{ dataset: { id: 1 } }];
    });

    this.chatService.updateLastReadMessage();
    await settled();

    assert.equal(this.chatService.activeChannel.lastSendReadMessageId, null);
  });

  test("#updateLastReadMessage - does nothing if the user already read the message", async function (assert) {
    this.currentUser.set("chat_channel_tracking_state", {});
    sinon.stub(document, "querySelectorAll").callsFake(function () {
      return [{ dataset: { id: 1 } }];
    });
    const activeChannel = fabricators.chatChannel({
      current_user_membership: { last_read_message_id: 2, following: true },
    });
    this.chatService.setActiveChannel(activeChannel);

    this.chatService.updateLastReadMessage();
    await settled();

    assert.equal(activeChannel.lastSendReadMessageId, 2);
  });
});

acceptance(
  "Discourse Chat | Unit | Service | chat - no current user",
  function (needs) {
    needs.hooks.beforeEach(function () {
      Object.defineProperty(this, "chatService", {
        get: () => this.container.lookup("service:chat"),
      });
    });

    test("#refreshTrackingState", async function (assert) {
      pretender.get(`/chat/chat_channels.json`, () => {
        assert.step("unexpected");
        return [200, { "Content-Type": "application/json" }, {}];
      });

      assert.step("start");
      await this.chatService.refreshTrackingState();
      assert.step("end");

      assert.verifySteps(["start", "end"], "it does no requests");
    });
  }
);

import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Unit | Service | chat-subscriptions-manager", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const owner = getOwner(this);

    this.subject = owner.lookup("service:chat-subscriptions-manager");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.fabricators = new ChatFabricators(owner);

    const messageBus = owner.lookup("service:message-bus");
    sinon.stub(messageBus, "subscribe");
    sinon.stub(messageBus, "unsubscribe");
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("read-only channel subscriptions skip user-scoped streams", function (assert) {
    const channel = this.fabricators.channel({
      id: 44,
      meta: {
        message_bus_last_ids: {
          new_messages: 3,
          new_mentions: 4,
          kick: 5,
        },
      },
    });

    this.subject.startChannelSubscription(channel, { readOnly: true });

    assert.deepEqual(this.subject.messageBus.subscribe.args, [
      ["/chat/44/new-messages", this.subject._onNewMessages, 3],
    ]);
  });

  test("new message updates public channel activity for anonymous users", async function (assert) {
    const channel = {
      id: 45,
      lastMessage: null,
      threadingEnabled: false,
      tracking: { unreadCount: 0 },
    };
    const message = {
      id: 99,
      user: { id: 2, username: "other_user" },
    };

    sinon.stub(this.chatChannelsManager, "find").resolves(channel);

    this.subject._onNewMessages({
      type: "channel",
      channel_id: channel.id,
      message,
    });

    await settled();

    assert.strictEqual(channel.lastMessage, message);
    assert.strictEqual(channel.tracking.unreadCount, 0);
  });
});

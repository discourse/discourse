import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatChannelSubscriptionManager from "discourse/plugins/chat/discourse/lib/chat-channel-subscription-manager";
import ChatChannelThreadSubscriptionManager from "discourse/plugins/chat/discourse/lib/chat-channel-thread-subscription-manager";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Unit | Lib | chat subscription managers",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      const owner = getOwner(this);

      this.fabricators = new ChatFabricators(owner);

      const messageBus = owner.lookup("service:message-bus");
      messageBus.subscribe = () => {};
      messageBus.unsubscribe = () => {};
    });

    test("channel manager syncs uploads when matching staged message is sent", function (assert) {
      const channel = this.fabricators.channel({ id: 11 });
      const manager = new ChatChannelSubscriptionManager(this, channel);
      manager.currentUser = { id: 1 };

      const stagedMessage = this.fabricators.message({
        id: "staged-1",
        channel,
        staged: true,
        processed: false,
        message: "",
        cooked: "",
        user: { id: 1, username: "current_user" },
        uploads: [{ id: 1, url: "/uploads/local.png", width: 16, height: 16 }],
      });
      channel.messagesManager.addMessages([stagedMessage]);

      manager.handleSentMessage({
        type: "sent",
        staged_id: "staged-1",
        chat_message: buildChatMessagePayload({
          id: 99,
          uploads: [
            {
              id: 1,
              url: "/uploads/server.png",
              short_path: "/uploads/short-url/server",
              width: 300,
              height: 200,
            },
          ],
        }),
      });

      assert.strictEqual(channel.messagesManager.messages.length, 1);
      assert.strictEqual(stagedMessage.id, 99);
      assert.false(stagedMessage.staged);
      assert.strictEqual(stagedMessage.uploads[0].url, "/uploads/server.png");
      assert.strictEqual(
        stagedMessage.uploads[0].short_path,
        "/uploads/short-url/server"
      );
    });

    test("thread manager syncs uploads when matching staged message is sent", function (assert) {
      const channel = this.fabricators.channel({ id: 12 });
      const thread = this.fabricators.thread({ id: 222, channel });
      const manager = new ChatChannelThreadSubscriptionManager(this, thread);
      manager.currentUser = { id: 1 };

      const stagedMessage = this.fabricators.message({
        id: "staged-2",
        channel,
        staged: true,
        processed: false,
        message: "",
        cooked: "",
        user: { id: 1, username: "current_user" },
        uploads: [
          { id: 2, url: "/uploads/local-thread.png", width: 20, height: 20 },
        ],
      });
      thread.messagesManager.addMessages([stagedMessage]);

      manager.handleSentMessage({
        type: "sent",
        staged_id: "staged-2",
        chat_message: buildChatMessagePayload({
          id: 109,
          uploads: [
            {
              id: 2,
              url: "/uploads/server-thread.png",
              short_path: "/uploads/short-url/server-thread",
              width: 640,
              height: 480,
            },
          ],
        }),
      });

      assert.strictEqual(thread.messagesManager.messages.length, 1);
      assert.strictEqual(stagedMessage.id, 109);
      assert.false(stagedMessage.staged);
      assert.strictEqual(
        stagedMessage.uploads[0].url,
        "/uploads/server-thread.png"
      );
      assert.strictEqual(
        stagedMessage.uploads[0].short_path,
        "/uploads/short-url/server-thread"
      );
    });
  }
);

function buildChatMessagePayload({ id, uploads }) {
  return {
    id,
    message: "",
    cooked: "",
    excerpt: "",
    created_at: "2024-01-01T00:00:00.000Z",
    user: {
      id: 1,
      username: "current_user",
    },
    uploads,
  };
}

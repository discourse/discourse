import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ChatThread from "discourse/plugins/chat/discourse/components/chat-thread";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";

module("Unit | Components | ChatThread", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new ChatFabricators(getOwner(this));

    pretender.get("/chat/api/channels/1/threads/1/messages", () =>
      response({
        messages: [],
        meta: {
          can_load_more_future: false,
          can_load_more_past: false,
        },
      })
    );
    pretender.post("/chat/api/channels/1/threads/1/drafts", () =>
      response({ success: true })
    );
  });

  function threadMessageRequests() {
    return pretender.handledRequests.filter(({ url }) =>
      url.startsWith("/chat/api/channels/1/threads/1/messages")
    );
  }

  test("fetches and scrolls to message when targetMessageId changes while pane is open", async function (assert) {
    const channel = this.fabricators.channel({ id: 1 });
    channel.currentUserMembership = UserChatChannelMembership.create({
      following: true,
    });
    const thread = this.fabricators.thread({ id: 1, channel });
    this.thread = thread;
    this.set("targetMessageId", null);

    await render(
      <template>
        <ChatThread
          @targetMessageId={{this.targetMessageId}}
          @thread={{this.thread}}
        />
      </template>
    );

    const requestsAfterMount = threadMessageRequests().length;

    this.set("targetMessageId", 42);
    await settled();

    const newRequests = threadMessageRequests().slice(requestsAfterMount);
    assert.strictEqual(
      newRequests.length,
      1,
      "one additional messages request after targetMessageId changes"
    );
    assert.true(
      newRequests[0].url.includes("target_message_id=42"),
      "request includes the target message ID"
    );
  });

  test("does not fetch when targetMessageId updates to null", async function (assert) {
    const channel = this.fabricators.channel({ id: 1 });
    channel.currentUserMembership = UserChatChannelMembership.create({
      following: true,
    });
    const thread = this.fabricators.thread({ id: 1, channel });
    this.thread = thread;
    this.set("targetMessageId", null);

    await render(
      <template>
        <ChatThread
          @targetMessageId={{this.targetMessageId}}
          @thread={{this.thread}}
        />
      </template>
    );

    const requestsAfterMount = threadMessageRequests().length;

    this.set("targetMessageId", null);
    await settled();

    assert.strictEqual(
      threadMessageRequests().length,
      requestsAfterMount,
      "no additional request when targetMessageId stays null"
    );
  });

  test("broadcast option follows the channel setting and toggles the draft", async function (assert) {
    const channel = this.fabricators.channel({ id: 1 });
    channel.currentUserMembership = UserChatChannelMembership.create({
      following: true,
    });
    const thread = this.fabricators.thread({ id: 1, channel });
    this.thread = thread;

    await render(
      <template>
        <ChatThread @targetMessageId={{null}} @thread={{this.thread}} />
      </template>
    );
    assert.dom(".chat-composer__broadcast-option").doesNotExist();

    channel.broadcastRepliesEnabled = true;
    await settled();
    assert.dom(".chat-composer__broadcast-option").exists();
    assert.dom(".chat-composer__broadcast-option input").isNotChecked();

    await click(".chat-composer__broadcast-option input");
    assert.true(thread.draft.broadcasted, "toggling marks the staged draft");
    assert.dom(".chat-composer__broadcast-option input").isChecked();
  });

  test("broadcast option uses DM wording in direct message channels", async function (assert) {
    const channel = this.fabricators.directMessageChannel({ id: 1 });
    channel.currentUserMembership = UserChatChannelMembership.create({
      following: true,
    });
    channel.broadcastRepliesEnabled = true;
    const thread = this.fabricators.thread({ id: 1, channel });
    this.thread = thread;

    await render(
      <template>
        <ChatThread @targetMessageId={{null}} @thread={{this.thread}} />
      </template>
    );

    assert.dom(".chat-composer__broadcast-option").hasText("Also reply in DM");
  });
});

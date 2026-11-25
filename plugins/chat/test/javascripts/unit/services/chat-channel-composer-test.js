import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Unit | Service | chat-channel-composer", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new ChatFabricators(getOwner(this));
    this.composer = getOwner(this).lookup("service:chat-channel-composer");
    this.router = getOwner(this).lookup("service:router");
    sinon.stub(this.router, "transitionTo").resolves();
  });

  test("replying to a broadcasted copy joins its thread instead of rooting a new one", async function (assert) {
    const channel = this.fabricators.channel();
    channel.threadingEnabled = true;
    const thread = this.fabricators.thread({ id: 42, channel });
    channel.threadsManager.add(channel, thread);
    // a broadcasted copy is serialized with thread_id and no thread object
    const message = this.fabricators.message({
      channel,
      broadcasted: true,
      thread_id: 42,
    });

    let created = false;
    pretender.post("/chat/api/channels/*/threads", () => {
      created = true;
      return response(200, { id: 99 });
    });

    await this.composer.replyTo(message);

    assert.false(created, "no thread is rooted on the broadcasted copy");
    assert.strictEqual(message.thread, thread, "joins the thread of the copy");
    assert.true(
      this.router.transitionTo.calledWith(
        "chat.channel.thread",
        ...thread.routeModels
      ),
      "opens that thread"
    );
  });

  test("replying to a message with no thread creates one", async function (assert) {
    const channel = this.fabricators.channel();
    channel.threadingEnabled = true;
    const message = this.fabricators.message({ channel });

    pretender.post("/chat/api/channels/*/threads", () =>
      response(200, { id: 99, title: "New thread" })
    );

    await this.composer.replyTo(message);

    assert.strictEqual(
      message.thread?.id,
      99,
      "roots a new thread on the message"
    );
    assert.true(
      this.router.transitionTo.calledWith(
        "chat.channel.thread",
        ...message.thread.routeModels
      ),
      "opens the new thread"
    );
  });
});

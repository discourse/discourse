import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  FUTURE,
  PAST,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatMessagesLoader from "discourse/plugins/chat/discourse/lib/chat-messages-loader";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Unit | Lib | chat-messages-loader", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(async function () {
    const owner = getOwner(this);
    this.channel = new ChatFabricators(owner).channel();
    this.channelMessages = sinon.stub(
      owner.lookup("service:chat-api"),
      "channelMessages"
    );
    this.loader = new ChatMessagesLoader(owner, this.channel);

    const fabricators = new ChatFabricators(owner);
    this.message = (id, args = {}) =>
      fabricators.message({ channel: this.channel, id, ...args });

    this.respondWith = (meta) =>
      this.channelMessages.resolves({ messages: [], meta });

    this.withMessages = async (...ids) => {
      this.channelMessages.resolves({
        messages: ids.map((id) => this.message(id)),
        meta: { can_load_more_past: true, can_load_more_future: true },
      });
      const result = await this.loader.load();
      this.channel.messagesManager.messages = result.messages;
    };

    this.pushMessage = (id, args = {}) =>
      this.channel.messagesManager.addMessages([this.message(id, args)]);

    this.lastRequest = () => this.channelMessages.lastCall.args[1];

    this.respondWith({ can_load_more_past: true, can_load_more_future: true });
    await this.loader.load();
  });

  test("loading past messages keeps the future flag", async function (assert) {
    this.respondWith({ can_load_more_past: false, can_load_more_future: null });

    await this.loader.loadMore({ direction: PAST });

    assert.false(this.loader.canLoadMorePast);
    assert.true(this.loader.canLoadMoreFuture);
  });

  test("loading future messages keeps the past flag", async function (assert) {
    this.respondWith({ can_load_more_past: null, can_load_more_future: false });

    await this.loader.loadMore({ direction: FUTURE });

    assert.true(this.loader.canLoadMorePast);
    assert.false(this.loader.canLoadMoreFuture);
  });

  test("reaching the real end of the stream stops future paging", async function (assert) {
    await this.withMessages(1, 2, 3);

    this.respondWith({
      can_load_more_past: null,
      can_load_more_future: false,
    });
    await this.loader.loadMore({ direction: FUTURE });
    const afterEnd = this.channelMessages.callCount;

    await this.loader.loadMore({ direction: FUTURE });

    assert.strictEqual(
      this.channelMessages.callCount,
      afterEnd,
      "no request once the server says there is nothing ahead"
    );
  });

  module("cursor ignores the rendered list", function () {
    test("pages from fetched messages, not ones added to the list", async function (assert) {
      await this.withMessages(1, 2, 3);
      this.pushMessage(99);

      this.respondWith({
        can_load_more_past: null,
        can_load_more_future: true,
      });
      await this.loader.loadMore({ direction: FUTURE });

      assert.strictEqual(
        this.lastRequest().target_message_id,
        3,
        "cursor is the last loaded message (3), not the live one (99)"
      );
    });

    test("staged messages are never used as the cursor", async function (assert) {
      await this.withMessages(1, 2, 3);
      this.pushMessage(100, { staged: true });

      this.respondWith({
        can_load_more_past: null,
        can_load_more_future: true,
      });
      await this.loader.loadMore({ direction: FUTURE });

      assert.strictEqual(
        this.lastRequest().target_message_id,
        3,
        "the in-flight own message is skipped as a cursor"
      );
    });
  });

  module("fetched window edges", function () {
    test("the first page seeds both edges", async function (assert) {
      await this.withMessages(15, 40, 65);

      this.respondWith({
        can_load_more_past: true,
        can_load_more_future: true,
      });
      await this.loader.loadMore({ direction: FUTURE });
      assert.strictEqual(this.lastRequest().target_message_id, 65);

      await this.loader.loadMore({ direction: PAST });
      assert.strictEqual(this.lastRequest().target_message_id, 15);
    });

    test("a released edge moves to its neighbour", async function (assert) {
      await this.withMessages(1, 2, 3, 4);
      const manager = this.channel.messagesManager;

      for (const id of [1, 4]) {
        const message = manager.findMessage(id);
        this.loader.releaseMessage(message);
        manager.removeMessage(message);
      }

      this.respondWith({
        can_load_more_past: true,
        can_load_more_future: true,
      });
      await this.loader.loadMore({ direction: PAST });
      assert.strictEqual(this.lastRequest().target_message_id, 2);

      await this.loader.loadMore({ direction: FUTURE });
      assert.strictEqual(this.lastRequest().target_message_id, 3);
    });

    test("an edge missing from the list without being released is kept", async function (assert) {
      await this.withMessages(1, 2, 3);
      this.channel.messagesManager.clear();

      this.respondWith({
        can_load_more_past: true,
        can_load_more_future: null,
      });
      await this.loader.loadMore({ direction: PAST });

      assert.strictEqual(this.lastRequest().target_message_id, 1);
    });

    test("an empty page leaves the window intact", async function (assert) {
      await this.withMessages(1, 2, 3);

      this.respondWith({
        can_load_more_past: null,
        can_load_more_future: false,
      });
      await this.loader.loadMore({ direction: FUTURE });

      this.respondWith({
        can_load_more_past: true,
        can_load_more_future: null,
      });
      await this.loader.loadMore({ direction: PAST });

      assert.strictEqual(
        this.lastRequest().target_message_id,
        1,
        "the oldest edge survives an empty future page"
      );
    });

    test("a failed page leaves the window intact", async function (assert) {
      await this.withMessages(1, 2, 3);

      this.channelMessages.rejects({ errors: ["boom"] });
      await this.loader.loadMore({ direction: FUTURE });

      this.respondWith({
        can_load_more_past: null,
        can_load_more_future: true,
      });
      await this.loader.loadMore({ direction: FUTURE });

      assert.strictEqual(
        this.lastRequest().target_message_id,
        3,
        "the newest edge survives a failed request"
      );
    });
  });

  module("live messages held back as pending", function () {
    test("a last page built before the live message is followed by one more", async function (assert) {
      await this.withMessages(1, 2, 3);
      this.loader.trackLiveMessage(this.message(10));

      const pages = [
        { messages: [4, 5, 6, 7, 8, 9], canFuture: false },
        { messages: [10], canFuture: false },
      ];
      this.channelMessages.callsFake(() => {
        const page = pages.shift();
        return Promise.resolve({
          messages: page.messages.map((id) => this.message(id)),
          meta: {
            can_load_more_past: null,
            can_load_more_future: page.canFuture,
          },
        });
      });

      const result = await this.loader.loadMore({ direction: FUTURE });

      assert.deepEqual(
        result.messages.map((m) => m.id),
        [4, 5, 6, 7, 8, 9, 10],
        "the follow-up page is merged into the result"
      );
      assert.strictEqual(this.lastRequest().target_message_id, 9);
      assert.false(this.loader.canLoadMoreFuture);
    });

    test("the follow-up to a first load pages from that load, before it is rendered", async function (assert) {
      this.loader.trackLiveMessage(this.message(10));
      this.channelMessages.resolves({
        messages: [7, 8, 9].map((id) => this.message(id)),
        meta: { can_load_more_past: true, can_load_more_future: false },
      });

      await this.loader.load();

      assert.strictEqual(this.lastRequest().target_message_id, 9);
    });

    test("only one follow-up is made for a message that never arrives", async function (assert) {
      await this.withMessages(1, 2, 3);
      this.loader.trackLiveMessage(this.message(10));
      this.respondWith({
        can_load_more_past: null,
        can_load_more_future: false,
      });
      const before = this.channelMessages.callCount;

      await this.loader.loadMore({ direction: FUTURE });
      await this.loader.load();

      assert.strictEqual(
        this.channelMessages.callCount,
        before + 3,
        "one page, one follow-up, then a plain reload"
      );
    });

    test("a failed follow-up leaves the channel loaded and retryable", async function (assert) {
      this.loader.trackLiveMessage(this.message(10));
      this.channelMessages.onCall(this.channelMessages.callCount).resolves({
        messages: [1, 2, 3].map((id) => this.message(id)),
        meta: { can_load_more_past: false, can_load_more_future: false },
      });
      this.channelMessages
        .onCall(this.channelMessages.callCount + 1)
        .rejects({ errors: ["boom"] });

      const result = await this.loader.load();

      assert.true(this.loader.fetchedOnce);
      assert.deepEqual(
        result.messages.map((m) => m.id),
        [1, 2, 3]
      );
      assert.true(
        this.loader.canLoadMoreFuture,
        "newer messages can still be requested"
      );

      this.channelMessages.resolves({
        messages: [this.message(10)],
        meta: { can_load_more_past: null, can_load_more_future: false },
      });
      const retry = await this.loader.loadMore({ direction: FUTURE });

      assert.strictEqual(this.lastRequest().target_message_id, 3);
      assert.deepEqual(
        retry.messages.map((m) => m.id),
        [10],
        "the held message is fetched on the next attempt"
      );
    });

    test("messages received at the live edge are not tracked", async function (assert) {
      await this.withMessages(1, 2, 3);
      this.respondWith({
        can_load_more_past: null,
        can_load_more_future: false,
      });
      await this.loader.loadMore({ direction: FUTURE });

      this.loader.trackLiveMessage(this.message(10));
      this.respondWith({
        can_load_more_past: true,
        can_load_more_future: null,
      });
      const before = this.channelMessages.callCount;
      await this.loader.loadMore({ direction: PAST });

      assert.strictEqual(this.channelMessages.callCount, before + 1);
    });
  });
});

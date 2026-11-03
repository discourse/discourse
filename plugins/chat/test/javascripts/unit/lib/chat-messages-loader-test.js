import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  DEFAULT_MESSAGE_PAGE_SIZE,
  FUTURE,
  PAST,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatMessagesLoader from "discourse/plugins/chat/discourse/lib/chat-messages-loader";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

// Chat::MessagesQuery PAST_MESSAGE_LIMIT / FUTURE_MESSAGE_LIMIT
const AROUND_TARGET_LIMIT = 25;

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

    // Mirrors Chat::MessagesQuery.
    this.useStream = (ids) => {
      this.channelMessages.callsFake((_channelId, params = {}) => {
        const size = params.page_size ?? DEFAULT_MESSAGE_PAGE_SIZE;
        const target = params.target_message_id;
        let page;
        let canFuture;
        let canPast;

        if (!params.direction) {
          if (target == null) {
            page = ids.slice(-size);
            canFuture = false;
            canPast = page.length === size;
          } else {
            const before = ids.filter((id) => id < target);
            const past = before.slice(
              Math.max(0, before.length - AROUND_TARGET_LIMIT)
            );
            const future = ids
              .filter((id) => id > target)
              .slice(0, AROUND_TARGET_LIMIT);
            page = [...past, target, ...future];
            canPast = past.length === AROUND_TARGET_LIMIT;
            canFuture = future.length === AROUND_TARGET_LIMIT;
          }
        } else if (params.direction === FUTURE) {
          page = ids.filter((id) => id > (target ?? 0)).slice(0, size);
          canFuture = page.length === size;
          canPast = null;
        } else {
          page = ids
            .filter((id) => target == null || id < target)
            .slice(-size)
            .reverse();
          canPast = page.length === size;
          canFuture = null;
        }

        return Promise.resolve({
          messages: page.map((id) => this.message(id)),
          meta: {
            can_load_more_past: canPast,
            can_load_more_future: canFuture,
          },
        });
      });
    };

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

  module("live message lands mid-stream", function () {
    test("the future page is still requested after a past page", async function (assert) {
      await this.withMessages(1, 2, 3);

      this.respondWith({
        can_load_more_past: true,
        can_load_more_future: null,
      });
      await this.loader.loadMore({ direction: PAST });

      this.pushMessage(99);

      this.respondWith({
        can_load_more_past: null,
        can_load_more_future: true,
      });
      const before = this.channelMessages.callCount;
      await this.loader.loadMore({ direction: FUTURE });

      assert.true(
        this.loader.canLoadMoreFuture,
        "the past page did not clobber the future flag"
      );
      assert.strictEqual(
        this.channelMessages.callCount,
        before + 1,
        "and the future page is still requested"
      );
    });

    test("the future page pages from the loaded window, not the live message", async function (assert) {
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

    test("paging forward reaches every message", async function (assert) {
      const stream = Array.from({ length: 61 }, (_, i) => i + 1);
      await this.withMessages(1, 2, 3);
      this.useStream(stream);
      this.pushMessage(61);

      const fetched = new Set(
        this.channel.messagesManager.messages.map((m) => m.id)
      );

      let guard = 0;
      while (this.loader.canLoadMoreFuture && guard++ < 10) {
        const result = await this.loader.loadMore({ direction: FUTURE });
        const loaded = result?.messages ?? [];
        if (loaded.length === 0) {
          break;
        }
        this.channel.messagesManager.addMessages(loaded);
        loaded.forEach((m) => fetched.add(m.id));
      }

      assert.deepEqual(
        stream.filter((id) => !fetched.has(id)),
        [],
        "no message is stranded between the loaded window and the live one"
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
  });

  module("fetched window edges", function () {
    test("opening at the last read seeds both edges", async function (assert) {
      this.useStream(Array.from({ length: 80 }, (_, i) => i + 1));

      await this.loader.load({ target_message_id: 40 });

      this.respondWith({
        can_load_more_past: true,
        can_load_more_future: true,
      });
      await this.loader.loadMore({ direction: FUTURE });
      assert.strictEqual(
        this.lastRequest().target_message_id,
        65,
        "future pages from the newest message of the window, not the target"
      );

      await this.loader.loadMore({ direction: PAST });
      assert.strictEqual(
        this.lastRequest().target_message_id,
        15,
        "past pages from the oldest message of the window"
      );
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

import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  install,
  subscriptions,
  uninstall,
} from "discourse/static/dev-tools/message-bus/instrumentation";

function channelsOf() {
  return window.MessageBus.callbacks.map((callback) => callback.channel);
}

module(
  "Unit | Lib | dev-tools | message-bus instrumentation",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.originalCallbacks = [...window.MessageBus.callbacks];
      window.MessageBus.callbacks.length = 0;
      install();
    });

    hooks.afterEach(function () {
      uninstall();
      window.MessageBus.callbacks.length = 0;
      window.MessageBus.callbacks.push(...this.originalCallbacks);
    });

    test("installing twice is a no-op", function (assert) {
      const before = window.MessageBus.subscribe;
      install();

      assert.strictEqual(window.MessageBus.subscribe, before);
    });

    test("subscribe returns the caller's own function", function (assert) {
      const handler = () => {};

      assert.strictEqual(
        window.MessageBus.subscribe("/a", handler),
        handler,
        "so a caller holding the return value can still unsubscribe with it"
      );
    });

    test("unsubscribe matches the caller's original function", function (assert) {
      const handler = () => {};
      window.MessageBus.subscribe("/a", handler);

      assert.true(window.MessageBus.unsubscribe("/a", handler));
      assert.deepEqual(channelsOf(), []);
    });

    test("one function subscribed to several channels unsubscribes from each", function (assert) {
      // The dominant pattern in Discourse: `topic-tracking-state` subscribes a
      // single bound method to four channels.
      const handler = () => {};
      window.MessageBus.subscribe("/latest", handler);
      window.MessageBus.subscribe("/new", handler);
      window.MessageBus.subscribe("/unread", handler);

      window.MessageBus.unsubscribe("/new", handler);
      assert.deepEqual(channelsOf(), ["/latest", "/unread"]);

      window.MessageBus.unsubscribe("/latest", handler);
      window.MessageBus.unsubscribe("/unread", handler);
      assert.deepEqual(channelsOf(), [], "none are left behind");
    });

    test("a glob unsubscribes every matching channel for that function", function (assert) {
      const handler = () => {};
      window.MessageBus.subscribe("/group/1", handler);
      window.MessageBus.subscribe("/group/2", handler);
      window.MessageBus.subscribe("/elsewhere", handler);

      assert.true(window.MessageBus.unsubscribe("/group/*", handler));
      assert.deepEqual(channelsOf(), ["/elsewhere"]);
    });

    test("a duplicate subscription is removed along with its twin", function (assert) {
      const handler = () => {};
      window.MessageBus.subscribe("/a", handler);
      window.MessageBus.subscribe("/a", handler);

      window.MessageBus.unsubscribe("/a", handler);

      assert.deepEqual(
        channelsOf(),
        [],
        "matching the library, which removes every match rather than the first"
      );
    });

    test("omitting the function unsubscribes the whole channel", function (assert) {
      window.MessageBus.subscribe("/a", () => {});
      window.MessageBus.subscribe("/a", () => {});
      window.MessageBus.subscribe("/b", () => {});

      window.MessageBus.unsubscribe("/a");

      assert.deepEqual(channelsOf(), ["/b"]);
    });

    test("unsubscribe('*') clears everything", function (assert) {
      // The test harness does this on every teardown.
      window.MessageBus.subscribe("/a", () => {});
      window.MessageBus.subscribe("/b", () => {});

      window.MessageBus.unsubscribe("*");

      assert.deepEqual(channelsOf(), []);
    });

    test("a subscription made before installing can still be unsubscribed", function (assert) {
      uninstall();

      const handler = () => {};
      window.MessageBus.subscribe("/a", handler);
      install();

      assert.true(window.MessageBus.unsubscribe("/a", handler));
      assert.deepEqual(channelsOf(), []);
    });

    test("unsubscribing something that is not subscribed reports false", function (assert) {
      assert.false(window.MessageBus.unsubscribe("/a", () => {}));
    });

    test("a subscriber's return value reaches the caller", async function (assert) {
      window.MessageBus.subscribe("/a", () =>
        Promise.resolve("from the subscriber")
      );

      const returned = window.MessageBus.callbacks[0].func();

      assert.strictEqual(await returned, "from the subscriber");
    });

    test("a subscriber's exception still propagates", function (assert) {
      window.MessageBus.subscribe("/a", () => {
        throw new Error("boom");
      });

      assert.throws(() => window.MessageBus.callbacks[0].func(), /boom/);
      assert.strictEqual(subscriptions()[0].errors, 1, "and is counted");
    });

    test("reports where a subscription was made and how often it ran", function (assert) {
      window.MessageBus.subscribe("/a", () => {});
      window.MessageBus.callbacks[0].func();
      window.MessageBus.callbacks[0].func();

      const [entry] = subscriptions();

      assert.strictEqual(entry.channel, "/a");
      assert.strictEqual(entry.calls, 2);
      assert.strictEqual(
        typeof entry.source,
        "string",
        "a source frame was captured"
      );
    });

    test("flags a channel with more than one subscription", function (assert) {
      window.MessageBus.subscribe("/a", () => {});
      window.MessageBus.subscribe("/a", () => {});
      window.MessageBus.subscribe("/b", () => {});

      const flagged = subscriptions().filter((entry) => entry.duplicated);

      assert.deepEqual(
        flagged.map((entry) => entry.channel),
        ["/a", "/a"]
      );
    });

    test("a later assignment to ajax stays behind the instrumentation", function (assert) {
      // The MessageBus instance initializer assigns `ajax` after dev tools
      // have loaded, replacing rather than wrapping it.
      let calledWith = null;
      window.MessageBus.ajax = (options) => {
        calledWith = options;
        return "from the replacement";
      };

      const result = window.MessageBus.ajax({ url: "/poll" });

      assert.strictEqual(result, "from the replacement", "the new one is used");
      assert.strictEqual(calledWith.url, "/poll", "with its options");
    });

    test("uninstall restores a plain ajax property", function (assert) {
      const replacement = () => {};
      window.MessageBus.ajax = replacement;

      uninstall();

      assert.strictEqual(window.MessageBus.ajax, replacement);
      assert.true(
        Object.getOwnPropertyDescriptor(window.MessageBus, "ajax").writable,
        "a data property again, so it can be redefined"
      );
    });

    test("the xhr factory is still called with its own options as context", function (assert) {
      // MessageBus' factory reads `this.messageBus`, so losing the receiver
      // would throw and take down every poll.
      let seenContext = null;
      const fakeXhr = { addEventListener() {} };

      window.MessageBus.ajax = (options) => options.xhr.call(options);

      window.MessageBus.ajax({
        messageBus: { chunked: true },
        xhr() {
          seenContext = this;
          return fakeXhr;
        },
      });

      assert.notStrictEqual(
        seenContext?.messageBus,
        undefined,
        "the receiver survived decoration"
      );
      assert.true(seenContext.messageBus.chunked);
    });
  }
);

import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  channelDetail,
  channelSummaries,
  clearCaptured,
  globalMessages,
  install,
  logSubscriberToConsole,
  messageBusState,
  recentUnsubscribes,
  setBusPaused,
  setCapturePaused,
  subscriptions,
  summary,
  uninstall,
} from "discourse/static/dev-tools/message-bus/instrumentation";
import devToolsState from "discourse/static/dev-tools/state";

const TOOL_ID = "message-bus";
const SETTING_KEYS = [
  "maxGlobalMessages",
  "maxChannelMessages",
  "maxTrackedChannels",
];

function frame(channel, messageId, globalId, data) {
  return {
    channel,
    message_id: messageId,
    global_id: globalId,
    data,
  };
}

/**
 * Runs a fake non-chunked poll: captures the options the instrumented `ajax`
 * hands to the underlying adapter, then delivers `payload` through the
 * decorated `success` exactly as message-bus-client would.
 */
function deliverViaSuccess(bus, payload, originalSuccess = () => {}) {
  let decorated;
  bus.ajax = (options) => {
    decorated = options;
  };
  bus.ajax({ messageBus: { chunked: false }, success: originalSuccess });
  return decorated.success(payload);
}

module(
  "Unit | Lib | dev-tools | message-bus-instrumentation-recording",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      uninstall();

      this.bus = window.MessageBus;
      this.originalCallbacks = [...this.bus.callbacks];
      this.originalSubscribe = this.bus.subscribe;
      this.originalUnsubscribe = this.bus.unsubscribe;
      this.originalAjaxDescriptor = Object.getOwnPropertyDescriptor(
        this.bus,
        "ajax"
      );
      this.originalLongPollDescriptor = Object.getOwnPropertyDescriptor(
        this.bus,
        "longPoll"
      );

      this.bus.callbacks.length = 0;
      this.bus.longPoll = null;
    });

    hooks.afterEach(function () {
      uninstall();

      this.bus.callbacks.length = 0;
      this.bus.callbacks.push(...this.originalCallbacks);
      this.bus.subscribe = this.originalSubscribe;
      this.bus.unsubscribe = this.originalUnsubscribe;
      Object.defineProperty(this.bus, "ajax", this.originalAjaxDescriptor);

      if (this.originalLongPollDescriptor) {
        Object.defineProperty(
          this.bus,
          "longPoll",
          this.originalLongPollDescriptor
        );
      } else {
        delete this.bus.longPoll;
      }

      for (const key of SETTING_KEYS) {
        devToolsState.setFlag(TOOL_ID, key, undefined);
      }
    });

    test("non-chunked success frames are recorded once and handed on untouched", function (assert) {
      install();

      const frames = [
        frame("/alpha", 1, 100, { a: 1 }),
        frame("/beta", 1, 101, { b: 2 }),
      ];
      let receivedMessages;
      let receivedThis;
      const marker = {};
      let decorated;

      this.bus.ajax = (options) => {
        decorated = options;
      };
      this.bus.ajax({
        messageBus: { chunked: false },
        success: function (messages) {
          receivedThis = this;
          receivedMessages = messages;
          return "handled";
        },
      });

      const returned = decorated.success.call(marker, frames);

      assert.strictEqual(
        returned,
        "handled",
        "the wrapper returns what the original success returned"
      );
      assert.strictEqual(
        receivedMessages,
        frames,
        "the original success receives the identical payload reference"
      );
      assert.strictEqual(
        receivedThis,
        marker,
        "the original success keeps its receiver"
      );
      assert.strictEqual(summary().polls, 1, "the poll was counted");

      const recorded = globalMessages();
      assert.strictEqual(recorded.length, 2, "each frame is recorded once");
      assert.strictEqual(
        recorded[0].channel,
        "/beta",
        "the stream is newest-first"
      );
      assert.strictEqual(recorded[1].channel, "/alpha");
      assert.strictEqual(recorded[1].messageId, 1);
      assert.strictEqual(recorded[1].globalId, 100);
      assert.strictEqual(
        recorded[1].data,
        frames[0].data,
        "payloads are stored by reference, not cloned"
      );
      assert.strictEqual(typeof recorded[0].receivedAt, "number");
      assert.strictEqual(typeof recorded[0].seq, "number");
      assert.notStrictEqual(
        recorded[0].seq,
        recorded[1].seq,
        "every recorded message gets its own sequence number"
      );
    });

    test("a JSON string body is parsed for recording but handed on verbatim", function (assert) {
      install();

      const body = JSON.stringify([frame("/text", 4, 200, { t: true })]);
      let receivedMessages;

      deliverViaSuccess(this.bus, body, (messages) => {
        receivedMessages = messages;
      });

      assert.strictEqual(
        receivedMessages,
        body,
        "the original success still receives the raw string it knows how to parse"
      );
      assert.strictEqual(globalMessages().length, 1);
      assert.strictEqual(globalMessages()[0].channel, "/text");
      assert.deepEqual(globalMessages()[0].data, { t: true });
    });

    test("/__status frames update server positions without entering histories", function (assert) {
      install();
      this.bus.subscribe("/watched", () => {}, 4);
      this.bus.callbacks[0].last_id = 4;

      deliverViaSuccess(this.bus, [
        frame("/__status", -1, -1, { "/watched": 7, "/unsubscribed": 3 }),
      ]);

      assert.strictEqual(
        globalMessages().length,
        0,
        "status meta-traffic is not a message"
      );
      assert.strictEqual(typeof summary().serverStatusAt, "number");

      const watched = channelSummaries().find(
        (row) => row.channel === "/watched"
      );
      assert.strictEqual(watched.serverPosition, 7);
      assert.strictEqual(watched.localPosition, 4);
      assert.strictEqual(
        watched.lag,
        3,
        "lag is the position difference, no clocks involved"
      );

      const unsubscribed = channelSummaries().find(
        (row) => row.channel === "/unsubscribed"
      );
      assert.strictEqual(
        unsubscribed.serverPosition,
        3,
        "a server position alone is enough to appear in the summaries"
      );
      assert.strictEqual(unsubscribed.subscriberCount, 0);
      assert.strictEqual(
        unsubscribed.lag,
        null,
        "lag needs both positions to mean anything"
      );
    });

    test("messages delivered through subscriber callbacks are recorded with their ids", function (assert) {
      install();
      this.bus.subscribe("/direct", () => {});

      this.bus.callbacks[0].func({ v: 1 }, 500, 3);

      const recorded = globalMessages();
      assert.strictEqual(recorded.length, 1);
      assert.strictEqual(recorded[0].channel, "/direct");
      assert.strictEqual(recorded[0].globalId, 500);
      assert.strictEqual(recorded[0].messageId, 3);
      assert.strictEqual(typeof subscriptions()[0].lastCallAt, "number");

      const detail = channelDetail("/direct");
      assert.strictEqual(detail.messages.length, 1);
      assert.strictEqual(detail.messages[0].globalId, 500);
    });

    test("a message seen by both transport and callback is recorded once, in either order", function (assert) {
      install();
      this.bus.subscribe("/both", () => {});
      const wrapper = this.bus.callbacks[0].func;

      // Transport first, then delivery — the non-chunked ordering.
      deliverViaSuccess(this.bus, [frame("/both", 9, 700, { n: 1 })]);
      wrapper({ n: 1 }, 700, 9);

      assert.strictEqual(globalMessages().length, 1);
      assert.strictEqual(
        subscriptions()[0].calls,
        1,
        "the callback still counted even though its message was already recorded"
      );

      // Delivery first, then transport — the chunked ordering.
      wrapper({ n: 2 }, 701, 10);
      deliverViaSuccess(this.bus, [frame("/both", 10, 701, { n: 2 })]);

      assert.strictEqual(globalMessages().length, 2);
    });

    test("synchronous fan-out to sibling subscribers records once", async function (assert) {
      install();
      this.bus.subscribe("/fan", () => {});
      this.bus.subscribe("/fan", () => {});
      const [first, second] = this.bus.callbacks.map((entry) => entry.func);

      const payload = { shared: true };
      first(payload);
      second(payload);

      assert.strictEqual(
        globalMessages().length,
        1,
        "the same publish reaching both siblings is one message"
      );
      assert.strictEqual(globalMessages()[0].messageId, null);
      assert.strictEqual(globalMessages()[0].globalId, null);

      await Promise.resolve();
      first(payload);

      assert.strictEqual(
        globalMessages().length,
        2,
        "a later publish of the same payload records again"
      );
    });

    test("per-channel history is capped while totals keep counting", function (assert) {
      install();

      for (let i = 0; i < 55; i++) {
        deliverViaSuccess(this.bus, [frame("/busy", i, 1000 + i, { i })]);
      }

      const detail = channelDetail("/busy");
      assert.strictEqual(
        detail.messages.length,
        50,
        "the default per-channel cap holds"
      );
      assert.strictEqual(
        detail.messageCount,
        55,
        "the total observed count keeps counting past the cap"
      );
      assert.strictEqual(
        detail.messages[0].messageId,
        54,
        "history is newest-first and the oldest were dropped"
      );
      assert.strictEqual(
        globalMessages().length,
        55,
        "the global stream has its own, larger cap"
      );
    });

    test("cap overrides are read from session flags and clamped", function (assert) {
      install();

      devToolsState.setFlag(TOOL_ID, "maxChannelMessages", 15);
      for (let i = 0; i < 20; i++) {
        deliverViaSuccess(this.bus, [frame("/tuned", i, 2000 + i, { i })]);
      }
      assert.strictEqual(
        channelDetail("/tuned").messages.length,
        15,
        "a raised or lowered override applies"
      );

      devToolsState.setFlag(TOOL_ID, "maxChannelMessages", 3);
      for (let i = 0; i < 12; i++) {
        deliverViaSuccess(this.bus, [frame("/clamped", i, 3000 + i, { i })]);
      }
      assert.strictEqual(
        channelDetail("/clamped").messages.length,
        10,
        "an absurdly small override is clamped to the minimum"
      );

      devToolsState.setFlag(TOOL_ID, "maxGlobalMessages", 10);
      deliverViaSuccess(this.bus, [frame("/one-more", 1, 4000, {})]);
      assert.strictEqual(
        globalMessages().length,
        10,
        "the global stream shrinks to a lowered cap as soon as it is enforced"
      );
    });

    test("tracked-channel eviction prefers subscriber-less channels and is counted", function (assert) {
      install();
      devToolsState.setFlag(TOOL_ID, "maxTrackedChannels", 50);

      this.bus.subscribe("/keep-me", () => {});
      deliverViaSuccess(this.bus, [frame("/keep-me", 1, 5000, {})]);

      for (let i = 0; i < 54; i++) {
        deliverViaSuccess(this.bus, [frame(`/evict/${i}`, 1, 5100 + i, {})]);
      }

      assert.strictEqual(
        summary().evictedChannelCount,
        5,
        "each channel dropped over the cap is counted"
      );
      assert.strictEqual(
        channelDetail("/evict/0"),
        null,
        "the oldest subscriber-less channel was evicted"
      );
      assert.notStrictEqual(
        channelDetail("/keep-me"),
        null,
        "an older channel with a live subscriber is preferred for keeping"
      );
      assert.notStrictEqual(channelDetail("/evict/53"), null);
    });

    test("subscription lifetimes are tracked", function (assert) {
      const preInstall = { channel: "/before", func: () => {}, last_id: -1 };
      this.bus.callbacks.push(preInstall);

      const before = Date.now();
      install();
      this.bus.subscribe("/after", () => {});

      const rows = subscriptions();
      const beforeRow = rows.find((row) => row.channel === "/before");
      const afterRow = rows.find((row) => row.channel === "/after");

      assert.strictEqual(
        beforeRow.subscribedAt,
        null,
        "a subscription that predates dev tools has no known start"
      );
      assert.true(afterRow.subscribedAt >= before);
      assert.strictEqual(afterRow.lastCallAt, null);

      this.bus.callbacks.find((entry) => entry.channel === "/after").func({});
      assert.strictEqual(
        typeof subscriptions().find((row) => row.channel === "/after")
          .lastCallAt,
        "number"
      );
    });

    test("unsubscribing records a capped churn log, newest first", function (assert) {
      install();

      const handler = () => {};
      this.bus.subscribe("/churn", handler);
      this.bus.callbacks[0].func({});
      this.bus.callbacks[0].func({});
      this.bus.unsubscribe("/churn", handler);

      const [entry] = recentUnsubscribes();
      assert.strictEqual(entry.channel, "/churn");
      assert.strictEqual(entry.calls, 2);
      assert.strictEqual(entry.errors, 0);
      assert.strictEqual(typeof entry.subscribedAt, "number");
      assert.strictEqual(typeof entry.unsubscribedAt, "number");
      assert.strictEqual(typeof entry.source, "string");

      for (let i = 0; i < 54; i++) {
        const churner = () => {};
        this.bus.subscribe(`/churn/${i}`, churner);
        this.bus.unsubscribe(`/churn/${i}`, churner);
      }

      assert.strictEqual(
        recentUnsubscribes().length,
        50,
        "the churn log is capped"
      );
      assert.strictEqual(
        recentUnsubscribes()[0].channel,
        "/churn/53",
        "the newest removal comes first"
      );
    });

    test("a channel is stamped when its last subscriber leaves and unstamped when one returns", function (assert) {
      install();

      const handler = () => {};
      this.bus.subscribe("/closing", handler);
      this.bus.callbacks[0].func({}, 11_000, 1);

      const closing = () =>
        channelSummaries().find((row) => row.channel === "/closing");
      const before = Date.now();

      this.bus.unsubscribe("/closing", handler);

      assert.strictEqual(
        typeof closing().closedAt,
        "number",
        "the moment a channel stopped being listened to is worth recording"
      );
      assert.true(closing().closedAt >= before);
      assert.strictEqual(closing().subscriberCount, 0);

      this.bus.subscribe("/closing", handler);

      assert.strictEqual(
        closing().closedAt,
        null,
        "a channel subscribed again is live, whatever it was a moment ago"
      );
      assert.strictEqual(closing().subscriberCount, 1);

      const first = () => {};
      const second = () => {};
      this.bus.subscribe("/pair", first);
      this.bus.subscribe("/pair", second);
      this.bus.callbacks
        .find((entry) => entry.channel === "/pair")
        .func({}, 11_001, 1);

      const pair = () =>
        channelSummaries().find((row) => row.channel === "/pair");
      assert.strictEqual(pair().closedAt, null);

      this.bus.unsubscribe("/pair", first);
      assert.strictEqual(
        pair().closedAt,
        null,
        "a channel closes when its last subscriber leaves, not its first"
      );

      this.bus.unsubscribe("/pair", second);
      assert.strictEqual(typeof pair().closedAt, "number");
    });

    test("channel detail carries the subscribers a channel has lost, newest first", function (assert) {
      install();

      const first = () => {};
      const second = () => {};
      const other = () => {};

      this.bus.subscribe("/past", first);
      this.bus.callbacks[0].func({}, 12_000, 1);
      this.bus.subscribe("/past", second);
      this.bus.subscribe("/other", other);

      this.bus.unsubscribe("/past", first);
      this.bus.unsubscribe("/past", second);
      this.bus.unsubscribe("/other", other);

      const detail = channelDetail("/past");
      assert.strictEqual(
        detail.pastSubscribers.length,
        2,
        "one entry per removal, and only this channel's"
      );

      const [newest, oldest] = detail.pastSubscribers;
      assert.true(newest.seq > oldest.seq, "the removals read newest first");
      assert.strictEqual(newest.channel, "/past");
      assert.strictEqual(typeof newest.subscribedAt, "number");
      assert.strictEqual(typeof newest.unsubscribedAt, "number");
      assert.strictEqual(typeof newest.source, "string");
      assert.strictEqual(
        oldest.calls,
        1,
        "the counters a subscription accumulated leave with it"
      );
      assert.strictEqual(oldest.errors, 0);
      assert.strictEqual(
        detail.subscribers.length,
        0,
        "a removed subscription is not also a live one"
      );

      assert.deepEqual(
        channelDetail("/other").pastSubscribers.map((entry) => entry.channel),
        ["/other"],
        "a channel does not inherit another channel's churn"
      );
    });

    test("channel detail opens for a channel known only by its position or its closure", function (assert) {
      install();

      deliverViaSuccess(this.bus, [
        frame("/__status", -1, -1, { "/positions-only": 12 }),
      ]);

      const positions = channelDetail("/positions-only");
      assert.notStrictEqual(
        positions,
        null,
        // The summaries already list it, so returning null here is a row that
        // reports a lag and then refuses to say anything about it.
        "a channel the server reports a position for can be opened"
      );
      assert.strictEqual(positions.serverPosition, 12);
      assert.deepEqual(positions.subscribers, []);
      assert.deepEqual(positions.messages, []);
      assert.deepEqual(positions.pastSubscribers, []);
      assert.strictEqual(positions.messageCount, 0);

      const gone = () => {};
      this.bus.subscribe("/quiet", gone);
      this.bus.unsubscribe("/quiet", gone);

      const quiet = channelDetail("/quiet");
      assert.notStrictEqual(
        quiet,
        null,
        "a channel that said nothing can still be opened once its subscriber leaves"
      );
      assert.strictEqual(
        quiet.messageCount,
        0,
        "there is nothing to show but who was there"
      );
      assert.strictEqual(quiet.pastSubscribers.length, 1);

      const quietRow = channelSummaries().find(
        ({ channel }) => channel === "/quiet"
      );
      assert.strictEqual(
        typeof quietRow?.closedAt,
        "number",
        // A message-less channel has no record and no position, so without
        // the stamp joining the membership union it would vanish from both
        // tables while its history still exists.
        "the closed stamp alone keeps a silent channel listed"
      );

      assert.strictEqual(
        channelDetail("/never-heard-of"),
        null,
        "a channel with no trace at all is still nothing to open"
      );
    });

    test("capture pause freezes recording while delivery continues", function (assert) {
      install();

      let delivered = 0;
      const failure = new Error("still thrown");
      this.bus.subscribe("/paused", () => {
        delivered++;
        return "through";
      });
      this.bus.subscribe("/paused-failing", () => {
        throw failure;
      });

      setCapturePaused(true);
      assert.true(summary().capturePaused);

      deliverViaSuccess(this.bus, [frame("/paused", 1, 6000, {})]);
      assert.strictEqual(globalMessages().length, 0);
      assert.strictEqual(summary().polls, 0, "polls are not counted either");

      const returned = this.bus.callbacks[0].func({});
      assert.strictEqual(delivered, 1, "the subscriber still runs");
      assert.strictEqual(returned, "through", "returns still pass through");
      assert.strictEqual(
        subscriptions()[0].calls,
        0,
        "its stats are not recorded"
      );

      assert.throws(
        () => this.bus.callbacks[1].func({}),
        /still thrown/,
        "exceptions still propagate"
      );
      assert.strictEqual(subscriptions()[1].errors, 0);

      this.bus.subscribe("/while-paused", () => {});
      assert.strictEqual(
        typeof subscriptions().find((row) => row.channel === "/while-paused")
          .subscribedAt,
        "number",
        "lifecycle facts are exempt from the pause"
      );

      setCapturePaused(false);
      deliverViaSuccess(this.bus, [frame("/paused", 2, 6001, {})]);
      assert.strictEqual(globalMessages().length, 1, "resume records again");
    });

    test("clearCaptured drops observations but keeps subscription identity", function (assert) {
      install();

      const handler = () => {};
      this.bus.subscribe("/cleared", handler);
      this.bus.callbacks[0].func({}, 7000, 1);
      deliverViaSuccess(this.bus, [
        frame("/__status", -1, -1, { "/cleared": 9 }),
      ]);

      const goner = () => {};
      this.bus.subscribe("/gone", goner);
      this.bus.unsubscribe("/gone", goner);

      const rowBefore = subscriptions()[0];
      const seqBefore = globalMessages()[0].seq;

      clearCaptured();

      assert.deepEqual(globalMessages(), []);
      assert.deepEqual(recentUnsubscribes(), []);
      assert.strictEqual(summary().polls, 0);
      assert.strictEqual(summary().serverStatusAt, null);
      assert.strictEqual(summary().evictedChannelCount, 0);

      const cleared = channelSummaries().find(
        (row) => row.channel === "/cleared"
      );
      assert.strictEqual(cleared.messageCount, 0);
      assert.strictEqual(cleared.serverPosition, null);

      const rowAfter = subscriptions()[0];
      assert.strictEqual(rowAfter.calls, 0);
      assert.strictEqual(rowAfter.slowestMs, 0);
      assert.strictEqual(rowAfter.lastCallAt, null);
      assert.strictEqual(
        rowAfter.subscribedAt,
        rowBefore.subscribedAt,
        "when it was subscribed is a fact, not an observation"
      );
      assert.strictEqual(
        rowAfter.source,
        rowBefore.source,
        "where it was subscribed is kept too"
      );

      this.bus.callbacks[0].func({}, 7001, 2);
      assert.true(
        globalMessages()[0].seq > seqBefore,
        "sequence numbers stay unique across clears"
      );
    });

    test("clearing forgets the closed channels and keeps the live ones", function (assert) {
      install();

      const live = () => {};
      const gone = () => {};
      this.bus.subscribe("/live", live);
      this.bus.subscribe("/gone", gone);
      this.bus.callbacks
        .find((entry) => entry.channel === "/gone")
        .func({}, 15_000, 1);
      this.bus.unsubscribe("/gone", gone);

      deliverViaSuccess(this.bus, [
        frame("/__status", -1, -1, { "/live": 9, "/gone": 4, "/orphan": 2 }),
      ]);

      const before = channelSummaries();
      assert.deepEqual(
        before.map((row) => row.channel),
        ["/gone", "/live", "/orphan"]
      );
      assert.strictEqual(
        typeof before.find((row) => row.channel === "/gone").closedAt,
        "number"
      );

      clearCaptured();

      assert.deepEqual(
        channelSummaries().map((row) => row.channel),
        ["/live"],
        // Clearing is how the panel is pointed at what happens next, so a
        // channel that is only remembered has nothing to contribute after one.
        "a clear leaves the table describing what is subscribed right now"
      );
      assert.strictEqual(channelSummaries()[0].closedAt, null);
      assert.strictEqual(
        channelDetail("/gone"),
        null,
        "a closed stamp is an observation, and observations do not survive a clear"
      );
      assert.strictEqual(channelDetail("/orphan"), null);
    });

    test("channel summaries aggregate their subscriptions and sort by channel", function (assert) {
      install();

      this.bus.subscribe("/bbb", () => {}, 5);
      this.bus.subscribe("/bbb", () => {}, 9);
      this.bus.subscribe("/aaa", () => {});

      this.bus.callbacks[0].last_id = 5;
      this.bus.callbacks[1].last_id = 9;
      this.bus.callbacks[0].func({}, 8000, 6);
      this.bus.callbacks[1].func({}, 8001, 10);

      const rows = channelSummaries();
      assert.deepEqual(
        rows.map((row) => row.channel),
        ["/aaa", "/bbb"],
        "rows are sorted by channel for stable rendering"
      );

      const bbb = rows[1];
      assert.strictEqual(bbb.subscriberCount, 2);
      assert.true(bbb.duplicated);
      assert.strictEqual(bbb.localPosition, 9, "the furthest position wins");
      assert.strictEqual(bbb.calls, 2, "calls are summed across subscribers");
      assert.strictEqual(bbb.messageCount, 2);
      assert.strictEqual(typeof bbb.lastMessageAt, "number");

      const aaa = rows[0];
      assert.false(aaa.duplicated);
      assert.strictEqual(aaa.messageCount, 0);
      assert.strictEqual(aaa.lastMessageAt, null);
    });

    test("summary counts channels rather than rows and guards status()", function (assert) {
      install();

      this.bus.subscribe("/twice", () => {});
      this.bus.subscribe("/twice", () => {});
      this.bus.subscribe("/once", () => {});

      const counters = summary();
      assert.strictEqual(counters.subscriptionCount, 3);
      assert.strictEqual(counters.duplicatedChannelCount, 1);
      assert.strictEqual(counters.channelCount, channelSummaries().length);

      const originalStatus = this.bus.status;
      try {
        this.bus.status = () => "started";
        assert.strictEqual(summary().busStatus, "started");

        this.bus.status = () => {
          throw new Error("not started");
        };
        assert.strictEqual(
          summary().busStatus,
          null,
          "a status that throws before first start reads as unknown"
        );

        delete this.bus.status;
        assert.strictEqual(summary().busStatus, null);
      } finally {
        this.bus.status = originalStatus;
      }
    });

    test("logSubscriberToConsole logs the captured source and the original callback", function (assert) {
      const preInstall = { channel: "/opaque", func: () => {}, last_id: -1 };
      this.bus.callbacks.push(preInstall);
      install();

      const handler = () => {};
      this.bus.subscribe("/traceable", handler);

      const logged = [];
      /* eslint-disable no-console */
      const originalLog = console.log;
      console.log = (...args) => logged.push(args);

      try {
        const traceable = subscriptions().find(
          (row) => row.channel === "/traceable"
        );
        logSubscriberToConsole(traceable.id);

        const flat = logged.flat();
        assert.true(
          flat.some((arg) => arg instanceof Error),
          "the captured Error is logged so the console can source-map its stack"
        );
        assert.true(
          flat.includes(handler),
          "the original callback is logged for jump-to-definition"
        );

        logged.length = 0;
        const opaque = subscriptions().find((row) => row.channel === "/opaque");
        logSubscriberToConsole(opaque.id);
        assert.true(
          logged.length > 0,
          "a subscription without a captured source still explains itself"
        );
        assert.false(
          logged.flat().some((arg) => arg instanceof Error),
          "there is no Error to log for a pre-install subscription"
        );

        logged.length = 0;
        logSubscriberToConsole("/nowhere#0");
        assert.true(
          logged.length > 0,
          "an unknown id logs a hint rather than throwing"
        );
      } finally {
        console.log = originalLog;
        /* eslint-enable no-console */
      }
    });

    test("setBusPaused drives the real bus and nothing else", function (assert) {
      install();

      const calls = [];
      const originalPause = this.bus.pause;
      const originalResume = this.bus.resume;

      try {
        this.bus.pause = () => calls.push("pause");
        this.bus.resume = () => calls.push("resume");

        setBusPaused(true);
        setBusPaused(false);

        assert.deepEqual(calls, ["pause", "resume"]);
        assert.false(
          summary().capturePaused,
          "the real bus control never implies a capture pause"
        );
      } finally {
        this.bus.pause = originalPause;
        this.bus.resume = originalResume;
      }
    });

    test("malformed transport payloads are ignored without breaking the poll", function (assert) {
      install();

      let delivered;
      deliverViaSuccess(this.bus, "not json at all", (messages) => {
        delivered = messages;
      });
      deliverViaSuccess(this.bus, { not: "an array" });
      deliverViaSuccess(this.bus, null);

      assert.strictEqual(
        delivered,
        "not json at all",
        "the original success still receives whatever arrived"
      );
      assert.deepEqual(globalMessages(), [], "nothing bogus was recorded");
    });

    test("eviction falls back to the oldest channel when every channel is live", function (assert) {
      install();
      devToolsState.setFlag(TOOL_ID, "maxTrackedChannels", 50);

      for (let i = 0; i < 51; i++) {
        this.bus.subscribe(`/live/${i}`, () => {});
        deliverViaSuccess(this.bus, [frame(`/live/${i}`, 1, 10_000 + i, {})]);
      }

      assert.strictEqual(summary().evictedChannelCount, 1);
      assert.strictEqual(
        channelDetail("/live/0").messages.length,
        0,
        "the oldest live channel lost its history"
      );
      assert.notStrictEqual(
        channelDetail("/live/50"),
        null,
        "the newest keeps its record"
      );
    });

    test("uninstall clears every new collection", function (assert) {
      install();

      this.bus.subscribe("/reset", () => {});
      deliverViaSuccess(this.bus, [
        frame("/reset", 1, 9000, {}),
        frame("/__status", -1, -1, { "/reset": 5 }),
      ]);
      const goner = () => {};
      this.bus.subscribe("/reset-gone", goner);
      this.bus.unsubscribe("/reset-gone", goner);
      setCapturePaused(true);

      uninstall();

      assert.deepEqual(globalMessages(), []);
      assert.deepEqual(recentUnsubscribes(), []);
      assert.deepEqual(channelSummaries(), []);
      assert.strictEqual(messageBusState().polls, 0);
      assert.false(messageBusState().paused);
      assert.strictEqual(messageBusState().serverStatusAt, null);
    });
  }
);

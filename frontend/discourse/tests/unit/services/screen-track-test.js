import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | screen-track", function (hooks) {
  setupTest(hooks);

  test("consolidateTimings", async function (assert) {
    const tracker = this.owner.lookup("service:screen-track");

    tracker.consolidateTimings({ 1: 10, 2: 5 }, 10, 1);
    tracker.consolidateTimings({ 1: 5, 3: 1 }, 3, 1);
    const consolidated = tracker.consolidateTimings({ 1: 5, 3: 1, 4: 5 }, 3, 2);

    assert.deepEqual(
      consolidated,
      [
        { timings: { 1: 15, 2: 5, 3: 1 }, topicTime: 13, topicId: 1 },
        { timings: { 1: 5, 3: 1, 4: 5 }, topicTime: 3, topicId: 2 },
      ],
      "expecting consolidated timings to match correctly"
    );

    await tracker.sendNextConsolidatedTiming();

    assert.strictEqual(
      tracker.highestReadFromCache(2),
      4,
      "caches highest read post number for second topic"
    );
  });

  test("appEvent topic:timings-sent is triggered after posting consolidated timings", async function (assert) {
    const tracker = this.owner.lookup("service:screen-track");
    const appEvents = this.owner.lookup("service:app-events");

    appEvents.on("topic:timings-sent", () => {
      assert.step("sent");
    });

    tracker.consolidateTimings({ 1: 10, 2: 5 }, 10, 1);
    await tracker.sendNextConsolidatedTiming();

    await assert.verifySteps(["sent"]);
  });

  module("observePost / unobservePost", function (nestedHooks) {
    let tracker, origIO, ioInstances;

    nestedHooks.beforeEach(function () {
      tracker = this.owner.lookup("service:screen-track");
      ioInstances = [];

      origIO = window.IntersectionObserver;
      window.IntersectionObserver = class {
        constructor(callback, options) {
          this.callback = callback;
          this.options = options;
          this.observed = new Set();
          ioInstances.push(this);
        }

        observe(el) {
          this.observed.add(el);
        }

        unobserve(el) {
          this.observed.delete(el);
        }

        disconnect() {
          this.observed.clear();
        }

        triggerEntry(el, isIntersecting) {
          this.callback([{ target: el, isIntersecting }]);
        }
      };
    });

    nestedHooks.afterEach(function () {
      tracker._destroyObserver();
      window.IntersectionObserver = origIO;
    });

    test("observePost creates an IntersectionObserver lazily", function (assert) {
      const el = document.createElement("div");
      const post = { post_number: 2, read: false };

      assert.strictEqual(ioInstances.length, 0);

      tracker.observePost(el, post);

      assert.strictEqual(ioInstances.length, 1);
      assert.true(ioInstances[0].observed.has(el));
    });

    test("observePost reuses existing observer", function (assert) {
      const el1 = document.createElement("div");
      const el2 = document.createElement("div");

      tracker.observePost(el1, { post_number: 2, read: false });
      tracker.observePost(el2, { post_number: 3, read: false });

      assert.strictEqual(ioInstances.length, 1);
      assert.true(ioInstances[0].observed.has(el1));
      assert.true(ioInstances[0].observed.has(el2));
    });

    test("unobservePost removes element from observer", function (assert) {
      const el = document.createElement("div");
      tracker.observePost(el, { post_number: 2, read: false });

      tracker.unobservePost(el);

      assert.false(ioInstances[0].observed.has(el));
    });

    test("intersection callback updates _onscreen via setOnscreen", async function (assert) {
      const el = document.createElement("div");
      const post = { post_number: 5, read: false };

      tracker.observePost(el, post);

      ioInstances[0].triggerEntry(el, true);
      await settled();

      assert.deepEqual(tracker._onscreen, [5]);
      assert.deepEqual(tracker._readOnscreen, []);
    });

    test("separates read from unread posts", async function (assert) {
      const el1 = document.createElement("div");
      const el2 = document.createElement("div");

      tracker.observePost(el1, { post_number: 2, read: true });
      tracker.observePost(el2, { post_number: 3, read: false });

      ioInstances[0].triggerEntry(el1, true);
      ioInstances[0].triggerEntry(el2, true);
      await settled();

      assert.true(tracker._onscreen.includes(2));
      assert.true(tracker._onscreen.includes(3));
      assert.true(tracker._readOnscreen.includes(2));
      assert.false(tracker._readOnscreen.includes(3));
    });

    test("removes post from onscreen when exiting viewport", async function (assert) {
      const el = document.createElement("div");
      tracker.observePost(el, { post_number: 2, read: false });

      ioInstances[0].triggerEntry(el, true);
      await settled();
      assert.deepEqual(tracker._onscreen, [2]);

      ioInstances[0].triggerEntry(el, false);
      await settled();
      assert.deepEqual(tracker._onscreen, []);
    });

    test("unobservePost triggers sync to remove from onscreen", async function (assert) {
      const el = document.createElement("div");
      tracker.observePost(el, { post_number: 2, read: false });

      ioInstances[0].triggerEntry(el, true);
      await settled();
      assert.deepEqual(tracker._onscreen, [2]);

      tracker.unobservePost(el);
      await settled();
      assert.deepEqual(tracker._onscreen, []);
    });

    test("stop() destroys observer and clears state", function (assert) {
      const el = document.createElement("div");
      tracker.observePost(el, { post_number: 2, read: false });

      const mockController = {
        readPosts() {},
        get() {
          return null;
        },
      };
      tracker.start(1, mockController);
      tracker.stop();

      assert.strictEqual(tracker._observer, null);
      assert.deepEqual(tracker._observedPosts, {});
    });

    test("ignores entries for unknown elements", async function (assert) {
      const el = document.createElement("div");
      tracker.observePost(el, { post_number: 2, read: false });

      const unknown = document.createElement("div");
      ioInstances[0].triggerEntry(unknown, true);
      await settled();

      // Only the known element should appear if it intersects
      assert.deepEqual(tracker._onscreen, null);
    });
  });
});

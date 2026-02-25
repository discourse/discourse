import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import PostScreenTracker from "discourse/lib/post-screen-tracker";

module("Unit | Lib | post-screen-tracker", function (hooks) {
  setupTest(hooks);

  let tracker, mockScreenTrack, intersectionCallbacks;

  hooks.beforeEach(function () {
    intersectionCallbacks = [];

    // stub IntersectionObserver so we can manually fire entries
    this._origIO = window.IntersectionObserver;
    window.IntersectionObserver = class {
      constructor(callback, options) {
        intersectionCallbacks.push(callback);
        this.options = options;
        this.observedElements = new Set();
      }

      observe(el) {
        this.observedElements.add(el);
      }

      unobserve(el) {
        this.observedElements.delete(el);
      }

      disconnect() {
        this.observedElements.clear();
      }
    };

    mockScreenTrack = {
      calls: [],
      setOnscreen(onScreen, readOnScreen) {
        this.calls.push({
          onScreen: [...onScreen],
          readOnScreen: [...readOnScreen],
        });
      },
    };

    tracker = new PostScreenTracker(mockScreenTrack);
  });

  hooks.afterEach(function () {
    tracker.destroy();
    window.IntersectionObserver = this._origIO;
  });

  function fireEntry(target, isIntersecting) {
    for (const cb of intersectionCallbacks) {
      cb([{ target, isIntersecting }]);
    }
  }

  test("tracks intersecting posts and calls setOnscreen", async function (assert) {
    const el = document.createElement("div");
    const post = { post_number: 1, read: false };

    tracker.observe(el, post);
    fireEntry(el, true);
    await settled();

    assert.strictEqual(mockScreenTrack.calls.length, 1);
    assert.deepEqual(mockScreenTrack.calls[0].onScreen, [1]);
    assert.deepEqual(mockScreenTrack.calls[0].readOnScreen, []);
  });

  test("separates read posts from unread", async function (assert) {
    const el1 = document.createElement("div");
    const el2 = document.createElement("div");
    const unreadPost = { post_number: 1, read: false };
    const readPost = { post_number: 2, read: true };

    tracker.observe(el1, unreadPost);
    tracker.observe(el2, readPost);
    fireEntry(el1, true);
    fireEntry(el2, true);
    await settled();

    const lastCall = mockScreenTrack.calls.at(-1);
    assert.deepEqual(lastCall.onScreen.sort(), [1, 2]);
    assert.deepEqual(lastCall.readOnScreen, [2]);
  });

  test("removes post from onscreen when it stops intersecting", async function (assert) {
    const el = document.createElement("div");
    const post = { post_number: 3, read: true };

    tracker.observe(el, post);
    fireEntry(el, true);
    await settled();

    fireEntry(el, false);
    await settled();

    const lastCall = mockScreenTrack.calls.at(-1);
    assert.deepEqual(lastCall.onScreen, []);
    assert.deepEqual(lastCall.readOnScreen, []);
  });

  test("unobserve removes the post from tracking", async function (assert) {
    const el = document.createElement("div");
    const post = { post_number: 5, read: false };

    tracker.observe(el, post);
    fireEntry(el, true);
    await settled();

    tracker.unobserve(el);
    await settled();

    const lastCall = mockScreenTrack.calls.at(-1);
    assert.deepEqual(lastCall.onScreen, []);
    assert.deepEqual(lastCall.readOnScreen, []);
  });

  test("ignores entries for unknown elements", async function (assert) {
    const unknownEl = document.createElement("div");
    fireEntry(unknownEl, true);
    await settled();

    assert.strictEqual(mockScreenTrack.calls.length, 0);
  });

  test("headerOffset is applied as negative rootMargin", function (assert) {
    tracker.destroy();

    const createdObservers = [];
    const OrigStub = window.IntersectionObserver;
    window.IntersectionObserver = class extends OrigStub {
      constructor(callback, options) {
        super(callback, options);
        createdObservers.push(this);
      }
    };

    tracker = new PostScreenTracker(mockScreenTrack, { headerOffset: 60 });

    assert.strictEqual(createdObservers.length, 1);
    assert.strictEqual(
      createdObservers[0].options.rootMargin,
      "-60px 0px 0px 0px"
    );

    window.IntersectionObserver = OrigStub;
  });

  test("destroy clears all state", async function (assert) {
    const el = document.createElement("div");
    const post = { post_number: 1, read: false };

    tracker.observe(el, post);
    fireEntry(el, true);
    await settled();

    tracker.destroy();

    // After destroy, create a fresh tracker and confirm it starts clean
    tracker = new PostScreenTracker(mockScreenTrack);
    const el2 = document.createElement("div");
    tracker.observe(el2, { post_number: 99, read: true });
    fireEntry(el2, true);
    await settled();

    const lastCall = mockScreenTrack.calls.at(-1);
    assert.deepEqual(lastCall.onScreen, [99]);
    assert.false(lastCall.onScreen.includes(1));
  });
});

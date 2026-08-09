import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ObserverManager from "discourse/float-kit/components/d-sheet/observer-manager";

module("Unit | FloatKit | d-sheet observer manager", function (hooks) {
  let observerManager;
  let originalIntersectionObserver;
  let originalResizeObserver;

  hooks.beforeEach(function () {
    originalIntersectionObserver = window.IntersectionObserver;
    originalResizeObserver = window.ResizeObserver;
  });

  hooks.afterEach(function () {
    observerManager?.cleanup();
    observerManager = null;
    sinon.restore();
    window.IntersectionObserver = originalIntersectionObserver;
    window.ResizeObserver = originalResizeObserver;
  });

  test("repeated swipe-out observations keep one owned frame and wheel sequence", async function (assert) {
    const frames = new Map();
    const cancelledFrames = [];
    let intersectionCallback;
    let nextFrameId = 1;
    let swipeOutCount = 0;

    sinon.stub(window, "requestAnimationFrame").callsFake((callback) => {
      const frameId = nextFrameId++;
      frames.set(frameId, callback);
      return frameId;
    });
    sinon.stub(window, "cancelAnimationFrame").callsFake((frameId) => {
      cancelledFrames.push(frameId);
      frames.delete(frameId);
    });
    const addEventListener = sinon.spy(window, "addEventListener");
    const removeEventListener = sinon.spy(window, "removeEventListener");

    window.IntersectionObserver = class {
      constructor(callback) {
        intersectionCallback = callback;
      }

      disconnect() {}
      observe() {}
    };

    const controller = {
      content: document.createElement("div"),
      domAttributes: {
        disableScrollSnap() {},
        hideForSwipeOut() {},
      },
      handleSwipeOut() {
        swipeOutCount++;
      },
      isDestroyed: false,
      isDestroying: false,
      state: {
        openness: { isOpen: true },
        skip: { enableClosing() {} },
      },
      swipeDisabled: false,
      swipeOutDisabledWithDetent: false,
      view: document.createElement("div"),
    };
    observerManager = new ObserverManager(controller);
    observerManager.setupIntersectionObserver();
    window.dispatchEvent(new Event("wheel"));

    const observeSwipeOut = () => {
      intersectionCallback([{ isIntersecting: false }]);
    };
    const flushFrame = () => {
      const [frameId, callback] = frames.entries().next().value;
      frames.delete(frameId);
      callback(0);
    };
    const blockingWheelListeners = () =>
      addEventListener
        .getCalls()
        .filter(({ args }) => args[0] === "wheel" && args[2]?.passive === false)
        .map(({ args }) => args[1]);
    const listenerWasRemoved = (listener) =>
      removeEventListener
        .getCalls()
        .some(({ args }) => args[0] === "wheel" && args[1] === listener);

    observeSwipeOut();
    const firstFrame = frames.keys().next().value;
    observeSwipeOut();

    assert.deepEqual(
      cancelledFrames,
      [firstFrame],
      "a replacement observation cancels the previous frame"
    );
    assert.strictEqual(frames.size, 1, "only the latest frame remains owned");

    flushFrame();
    const firstWheelListener = blockingWheelListeners()[0];

    observeSwipeOut();
    flushFrame();
    const secondWheelListener = blockingWheelListeners()[1];

    assert.true(
      listenerWasRemoved(firstWheelListener),
      "a replacement wheel sequence releases its previous listener"
    );

    await settled();

    assert.strictEqual(
      swipeOutCount,
      1,
      "only the replacement wheel timer can trigger swipe-out"
    );
    assert.true(
      listenerWasRemoved(secondWheelListener),
      "the completed sequence releases its listener"
    );

    observeSwipeOut();
    flushFrame();
    const cleanupWheelListener = blockingWheelListeners()[2];
    observeSwipeOut();
    const cleanupFrame = frames.keys().next().value;

    observerManager.cleanup();
    observerManager = null;
    await settled();

    assert.true(
      cancelledFrames.includes(cleanupFrame),
      "cleanup cancels the pending replacement frame"
    );
    assert.true(
      listenerWasRemoved(cleanupWheelListener),
      "cleanup releases the active wheel listener"
    );
    assert.strictEqual(
      swipeOutCount,
      1,
      "cleanup cancels the active wheel timer"
    );
  });

  test("detached resize targets are unobserved", function (assert) {
    const observed = [];
    const unobserved = [];

    window.ResizeObserver = class {
      disconnect() {}

      observe(element) {
        observed.push(element);
      }

      unobserve(element) {
        unobserved.push(element);
      }
    };

    const view = document.createElement("div");
    const content = document.createElement("div");
    const manager = new ObserverManager({ content, view });

    manager.setupResizeObserver({ onResize() {} });
    manager.unobserveResizeTarget(view);
    manager.unobserveResizeTarget(content);

    assert.deepEqual(observed, [view, content], "both targets are observed");
    assert.deepEqual(
      unobserved,
      [view, content],
      "both detached targets are released"
    );
  });

  test("distinguishes initial observations from resize corrections", function (assert) {
    let observerCallback;
    const events = [];
    const observed = [];
    const unobserved = [];

    window.ResizeObserver = class {
      constructor(callback) {
        observerCallback = callback;
      }

      disconnect() {}
      observe(target) {
        observed.push(target);
      }

      unobserve(target) {
        unobserved.push(target);
      }
    };

    const view = document.createElement("div");
    const content = document.createElement("div");
    const manager = new ObserverManager({ content, view });

    manager.setupResizeObserver({
      onInitialContentResize() {
        events.push("initial content");
      },
      onResize() {
        events.push("resize");
      },
    });

    observerCallback([{ target: view }, { target: content }]);

    assert.deepEqual(
      events,
      ["initial content"],
      "the view is skipped and content is measured on their first delivery"
    );

    observerCallback([{ target: view }, { target: content }]);

    assert.deepEqual(
      events,
      ["initial content", "resize", "resize"],
      "later observations request correction travel"
    );

    manager.resetResizeObservationCycle();

    assert.deepEqual(
      unobserved,
      [view, content],
      "reset releases both targets from the previous delivery cycle"
    );
    assert.deepEqual(
      observed,
      [view, content, view, content],
      "reset observes both targets again to request a fresh delivery"
    );

    observerCallback([{ target: view }, { target: content }]);

    assert.deepEqual(
      events,
      ["initial content", "resize", "resize", "initial content"],
      "a reset treats the next geometry delivery as an initial observation"
    );

    observerCallback([{ target: view }, { target: content }]);

    assert.deepEqual(
      events,
      [
        "initial content",
        "resize",
        "resize",
        "initial content",
        "resize",
        "resize",
      ],
      "correction travel resumes after the reset delivery"
    );
  });
});

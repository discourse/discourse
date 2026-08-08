import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import Controller from "discourse/float-kit/components/d-sheet/controller";
import { EVENTS } from "discourse/float-kit/components/d-sheet/state-machine-events";
import { capabilities } from "discourse/services/capabilities";

function stubAnimationFrames() {
  const callbacks = new Map();
  let nextId = 1;

  sinon.stub(window, "requestAnimationFrame").callsFake((callback) => {
    const id = nextId++;
    callbacks.set(id, callback);
    return id;
  });
  sinon.stub(window, "cancelAnimationFrame").callsFake((id) => {
    callbacks.delete(id);
  });

  return {
    get size() {
      return callbacks.size;
    },
    flush(timestamp = 0) {
      const pendingCallbacks = [...callbacks];

      for (const [id, callback] of pendingCallbacks) {
        callbacks.delete(id);
        callback(timestamp);
      }
    },
  };
}

async function flushAnimationFrames(queue) {
  for (let iteration = 0; iteration < 10; iteration++) {
    await settled();

    if (queue.size === 0) {
      return;
    }

    queue.flush(iteration);
  }

  throw new Error("d-sheet animation frames did not settle");
}

module("Unit | FloatKit | d-sheet controller", function (hooks) {
  setupTest(hooks);
  hooks.afterEach(() => sinon.restore());

  test("synchronizes skip machines when animation settings change", function (assert) {
    const controller = new Controller();

    controller.configure({
      enteringAnimationSettings: { skip: true },
      exitingAnimationSettings: { skip: false },
    });

    assert.true(
      controller.state.skip.isOpening,
      "entering skip is enabled from normalized settings"
    );
    assert.false(
      controller.state.skip.isClosing,
      "exiting skip is disabled from normalized settings"
    );

    controller.configure({
      enteringAnimationSettings: { skip: false },
      exitingAnimationSettings: { skip: true },
    });

    assert.false(
      controller.state.skip.isOpening,
      "a dynamic entering setting disables opening skip"
    );
    assert.true(
      controller.state.skip.isClosing,
      "a dynamic exiting setting enables closing skip"
    );

    controller.cleanup();
  });

  test("clears persisted outlet styles when long-running work ends", async function (assert) {
    const controller = new Controller();
    const target = document.createElement("div");

    target.style.transform = "scale(0.9)";
    target.style.transformOrigin = "0 50%";
    controller.registerStackingAnimation({
      animatedProperties: new Set(["transform"]),
      target,
    });

    controller.state.longRunning.start();
    controller.state.longRunning.end();
    await settled();

    assert.strictEqual(
      target.style.transform,
      "",
      "the lifecycle removes the persisted animated value"
    );
    assert.notStrictEqual(
      target.style.transformOrigin,
      "",
      "the modifier-owned static value is retained"
    );

    target.style.transform = "scale(0.9)";
    controller.cleanup();

    assert.strictEqual(
      target.style.transform,
      "",
      "controller destruction provides the cleanup fallback"
    );
  });

  test("entering skip completes the skipped opening lifecycle", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const controller = new Controller();

    controller.configure({
      enteringAnimationSettings: { skip: true },
      swipe: false,
    });
    controller.open();

    assert.true(
      controller.state.staging.isOpen,
      "opening begins in Silk's skipped staging state"
    );

    await flushAnimationFrames(animationFrames);

    assert.true(
      controller.state.openness.isOpen,
      "the openness lifecycle reaches open"
    );
    assert.true(
      controller.state.position.isFrontIdle,
      "the position lifecycle reaches the front without animation"
    );
    assert.true(controller.state.staging.isNone, "skipped staging is cleared");
    assert.strictEqual(
      controller.travelStatus,
      "idleInside",
      "the public travel status reaches its open resting state"
    );

    controller.cleanup();
  });

  test("exiting skip runs immediate close effects exactly once", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const calls = [];
    const controller = new Controller();

    controller.configure({
      enteringAnimationSettings: { skip: true },
      exitingAnimationSettings: { skip: true },
      onTravel: ({ progress, range }) =>
        calls.push(`travel:${progress}:${range.start}-${range.end}`),
      onTravelEnd: () => calls.push("end"),
      onTravelStart: () => calls.push("start"),
      swipe: false,
    });
    controller.travelAnimations.push({
      callback: (progress) => calls.push(`animation:${progress}`),
    });
    sinon
      .stub(controller.stackingAdapter, "notifyBelowSheets")
      .callsFake((progress) => calls.push(`below:${progress}`));
    sinon
      .stub(controller.stackingAdapter, "updateTravelProgress")
      .callsFake((progress) => calls.push(`stack:${progress}`));
    sinon
      .stub(controller.stackingAdapter, "notifyParentOfClosingImmediate")
      .callsFake(() => calls.push("parent"));

    controller.open();
    await flushAnimationFrames(animationFrames);
    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];

    controller.close();

    assert.true(
      controller.state.openness.isClosedPending,
      "the sheet bypasses the closing animation state"
    );
    assert.true(
      controller.state.position.isOut,
      "the position lifecycle moves directly outside"
    );
    assert.true(
      controller.state.skip.isClosing,
      "the configured closing skip remains synchronized"
    );
    assert.deepEqual(
      calls,
      [
        "start",
        "travel:0:0-0",
        "animation:0",
        "below:0",
        "end",
        "stack:0",
        "parent",
      ],
      "travel, stacking, and parent effects run once in Silk's callback order"
    );

    controller.cleanup();
  });

  test("reduced motion skips both opening and closing lifecycles", async function (assert) {
    const animationFrames = stubAnimationFrames();
    sinon.stub(window, "matchMedia").callsFake((query) => ({
      matches: query === "(prefers-reduced-motion: reduce)",
    }));
    const controller = new Controller();

    controller.configure({ swipe: false });

    assert.true(
      controller.state.skip.isOpening,
      "reduced motion enables opening skip at construction"
    );
    assert.true(
      controller.state.skip.isClosing,
      "reduced motion enables closing skip at construction"
    );

    controller.open();
    await flushAnimationFrames(animationFrames);

    assert.true(
      controller.state.openness.isOpen,
      "reduced-motion opening reaches open"
    );

    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];
    controller.close();

    assert.true(
      controller.state.openness.isClosedPending,
      "reduced-motion closing reaches pending without animation"
    );

    controller.cleanup();
  });

  test("ignores swipe-out notifications after leaving open", function (assert) {
    const calls = [];
    const controller = new Controller();

    controller.configure({
      onActiveDetentChange: (detent) => calls.push(detent),
      swipe: false,
    });
    controller.state.openness.readyToOpen(true);

    controller.handleSwipeOut();
    controller.handleSwipeOut();

    assert.deepEqual(
      calls,
      [0],
      "only the accepted open-to-closed transition reports dismissal"
    );
    assert.true(
      controller.state.openness.isClosedPending,
      "a stale swipe-out leaves the pending lifecycle unchanged"
    );

    controller.cleanup();
  });

  test("suppresses resting notifications between accepted close stages", async function (assert) {
    stubAnimationFrames();
    const calls = [];
    const controller = new Controller();

    controller.configure({
      onActiveDetentChange: (detent) => calls.push(detent),
      swipe: false,
    });
    controller.state.openness.readyToOpen(true);
    controller.state.position.readyToGoFront(true);
    await Promise.resolve();
    calls.length = 0;

    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];
    controller.travelRange = { start: 1, end: 1 };
    controller.setSegment([0, 0]);
    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];

    controller.close();

    assert.deepEqual(calls, [0], "accepted dismissal reports immediately");

    await Promise.resolve();

    assert.deepEqual(
      calls,
      [0],
      "a queued resting segment remains suppressed before closing travel starts"
    );

    controller.handleStateTransition({ type: EVENTS.READY_TO_CLOSE });

    assert.deepEqual(
      calls,
      [0, 0],
      "closing travel reports Silk's second intentional dismissal callback"
    );

    controller.cleanup();
  });

  test("queues resting segment notifications after travel", async function (assert) {
    const controller = new Controller();
    const calls = [];

    controller.configure({
      onActiveDetentChange: (detent) => calls.push(`active:${detent}`),
      onTravel: () => calls.push("travel"),
      onTravelRangeChange: ({ start, end }) =>
        calls.push(`range:${start}-${end}`),
    });

    controller.setSegment([1, 1]);
    controller.notifyTravel(1);

    assert.deepEqual(
      controller.currentSegment,
      [1, 1],
      "the internal segment updates synchronously"
    );
    assert.deepEqual(
      calls,
      ["travel"],
      "travel is reported before queued segment notifications"
    );

    await Promise.resolve();

    assert.deepEqual(
      calls,
      ["travel", "range:1-1", "active:1"],
      "range and resting detent changes run in the following microtask"
    );

    controller.setSegment([1, 1]);
    await Promise.resolve();

    assert.deepEqual(
      calls,
      ["travel", "range:1-1", "active:1"],
      "an unchanged segment does not repeat public notifications"
    );

    controller.cleanup();
  });

  test("reports no range without a newly detected segment", function (assert) {
    const controller = new Controller();
    const progressAtDetents = [0, 0.5, 1];
    let payload;

    controller.dimensions = { exactProgressValueAtDetents: progressAtDetents };
    controller.configure({
      onTravel: (travel) => {
        payload = travel;
      },
    });
    controller.setSegment([1, 2]);

    controller.notifyTravel(0.75);

    assert.deepEqual(
      payload,
      {
        progress: 0.75,
        range: undefined,
        progressAtDetents,
      },
      "travel preserves the absence of a range and includes detent progress"
    );

    controller.cleanup();
  });

  test("suppresses programmatic detent notifications through travel completion", async function (assert) {
    const controller = new Controller();
    const calls = [];

    controller.configure({
      onActiveDetentChange: (detent) => calls.push(`active:${detent}`),
      onTravel: () => calls.push("travel"),
      onTravelRangeChange: ({ start, end }) =>
        calls.push(`range:${start}-${end}`),
      swipe: false,
    });
    controller.animationTravel.animateToDetent = (
      detent,
      _animationConfig,
      programmaticDetentTravel
    ) => {
      controller.setSegment([detent, detent]);
      controller.setSegment([0, detent]);
      controller.setSegment([detent, detent]);
      controller.notifyTravel(detent);
      controller.completeActiveDetentNotification(programmaticDetentTravel);
    };

    controller.handleStepMessage({ detent: 1 });

    assert.deepEqual(
      calls,
      ["active:1", "travel"],
      "the programmatic detent is reported immediately before travel"
    );

    await Promise.resolve();

    assert.deepEqual(
      calls,
      ["active:1", "travel", "range:1-1", "range:0-1", "range:1-1"],
      "resting-segment reentry stays suppressed until travel completes"
    );

    controller.setSegment([0, 1]);
    controller.setSegment([0, 0]);
    await Promise.resolve();

    assert.deepEqual(
      calls.slice(-3),
      ["range:0-1", "range:0-0", "active:0"],
      "manual resting changes notify after programmatic travel completes"
    );

    controller.cleanup();
  });

  test("instant travel releases programmatic detent suppression", async function (assert) {
    const calls = [];
    const controller = new Controller();

    controller.configure({
      onActiveDetentChange: (detent) => calls.push(detent),
      steppingAnimationSettings: { skip: true },
      swipe: false,
    });
    controller.view = document.createElement("div");
    controller.contentWrapper = document.createElement("div");
    controller.scrollContainer = {
      scrollLeft: 0,
      scrollTop: 0,
      scrollTo() {},
    };
    controller.dimensions = {
      content: { travelAxis: { unitless: 100 } },
      detentMarkers: [
        {
          accumulatedOffsets: { travelAxis: { unitless: 50 } },
          travelAxis: { unitless: 50 },
        },
        {
          accumulatedOffsets: { travelAxis: { unitless: 100 } },
          travelAxis: { unitless: 50 },
        },
      ],
      exactProgressValueAtDetents: [0, 0.5, 1],
      progressValueAtDetents: [{ exact: 0 }, { exact: 0.5 }, { exact: 1 }],
      snapOutAccelerator: { travelAxis: { unitless: 0 } },
      swipeOutDisabledWithDetent: false,
      view: { travelAxis: { unitless: 100 } },
    };
    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];
    controller.state.openness.readyToOpen(true);
    await Promise.resolve();
    calls.length = 0;

    controller.handleStepMessage({ detent: 2 });
    await Promise.resolve();

    assert.deepEqual(
      calls,
      [2],
      "instant resting travel is not reported twice"
    );

    controller.setSegment([0, 1]);
    controller.setSegment([0, 0]);
    await Promise.resolve();

    assert.deepEqual(
      calls,
      [2, 0],
      "instant travel releases suppression after its segment settles"
    );

    controller.cleanup();
  });

  test("a no-dimension travel releases programmatic detent suppression", async function (assert) {
    const calls = [];
    const controller = new Controller();

    controller.configure({
      onActiveDetentChange: (detent) => calls.push(detent),
      swipe: false,
    });

    controller.handleStepMessage({ detent: 1 });
    await Promise.resolve();

    controller.setSegment([0, 1]);
    controller.setSegment([1, 1]);
    await Promise.resolve();

    assert.deepEqual(
      calls,
      [1, 1],
      "the no-dimension fast path releases suppression for later manual rest"
    );

    controller.cleanup();
  });

  test("manual travel updates stacked progress only once at its exact end", function (assert) {
    const controller = new Controller();
    const calls = [];
    const frameProgress = [0.55, 0.6, 0.7];
    const sheetStackRegistry = {
      removeSheetStagingFromStack() {},
      updateSheetTravelProgress(_controller, progress) {
        calls.push(`registry:${progress}`);
      },
    };

    controller.configure({ swipe: false });
    controller.state.openness.readyToOpen(true);
    controller.configure({
      onTravelStart: () => calls.push("start"),
      onTravelEnd: () => calls.push("end"),
      sheetStackRegistry,
    });
    controller.stackId = "test-stack";
    controller.dimensions = {
      exactProgressValueAtDetents: [0, 0.5, 1],
      progressValueAtDetents: [
        { before: -0.01, exact: 0, after: 0.01 },
        { before: 0.49, exact: 0.5, after: 0.51 },
        { before: 0.99, exact: 1, after: 1.01 },
      ],
    };
    controller.currentSegment = [1, 1];
    controller.scrollProgressCalculator.calculateProgress = () => ({
      clampedProgress: frameProgress.shift(),
    });

    controller.state.openness.swipeStart();
    controller.processScrollProgress();
    controller.processScrollProgress();
    controller.processScrollProgress();

    assert.deepEqual(
      calls,
      ["start"],
      "manual frames do not rebuild the stack registry"
    );

    controller.state.openness.swipeEnd();

    assert.deepEqual(
      calls,
      ["start", "end", "registry:0.5"],
      "the public callback precedes one exact final registry update"
    );
    assert.strictEqual(
      controller.lastProcessedProgress,
      0.5,
      "the next gesture starts from the exact resting progress"
    );

    controller.cleanup();
  });

  test("swipe-out finalizes ongoing manual travel once", function (assert) {
    const controller = new Controller();
    const calls = [];

    controller.configure({
      onTravelStart: () => calls.push("start"),
      onTravelEnd: () => calls.push("end"),
      swipe: false,
    });
    controller.state.openness.readyToOpen(true);
    controller.dimensions = {
      exactProgressValueAtDetents: [0, 0.5, 1],
    };
    controller.currentSegment = [1, 1];
    controller.stackingAdapter.updateTravelProgress = (progress) =>
      calls.push(`registry:${progress}`);

    controller.state.openness.swipeStart();
    controller.handleSwipeOut();
    controller.handleManualTravelEnd();

    assert.deepEqual(
      calls,
      ["start", "end", "registry:0.5"],
      "leaving open ends the discarded swipe state without duplicate finalization"
    );

    controller.cleanup();
  });

  test("leaving open cleans up swipe-out observation", function (assert) {
    const controller = new Controller();
    let cleanupCount = 0;

    controller.configure({ swipe: false });
    controller.state.openness.readyToOpen(true);
    controller.cleanupIntersectionObserver = () => cleanupCount++;

    controller.state.openness.send(EVENTS.SWIPED_OUT);

    assert.strictEqual(
      cleanupCount,
      1,
      "the open-state exit releases its observer and wheel listeners"
    );

    controller.cleanup();
  });

  test("controlled dismiss waits for presentation synchronization", function (assert) {
    const controller = new Controller();
    const presentedChanges = [];

    controller.configure({ swipe: false });
    controller.state.openness.readyToOpen(true);
    controller.currentSegment = [1, 1];
    controller.rootComponent = {
      dismiss() {
        presentedChanges.push(false);
      },
    };

    controller.requestDismiss();

    assert.deepEqual(
      presentedChanges,
      [false],
      "the controlled Root receives the dismissal"
    );
    assert.true(
      controller.state.openness.isOpen,
      "the open lifecycle waits for the presented value to synchronize"
    );

    controller.cleanup();
  });

  test("focus inside uses a View-wide behavior event", function (assert) {
    const controller = new Controller();
    const view = document.createElement("div");
    const nativeEvent = { target: view };
    let behaviorEvent;

    controller.view = view;
    controller.scrollContainer = document.createElement("div");
    controller.onFocusInside = (event) => {
      behaviorEvent = event;
      event.changeDefault({ handled: true });
    };

    controller.handleFocus(nativeEvent);

    assert.strictEqual(
      behaviorEvent.nativeEvent,
      nativeEvent,
      "the behavior event exposes the native focus event"
    );
    assert.true(
      behaviorEvent.handled,
      "changeDefault updates the behavior event"
    );

    controller.cleanup();
  });

  test("each close request is evaluated once at the initial segment", function (assert) {
    const controller = new Controller();
    const evaluatedSegments = [];
    const evaluateCloseMessage =
      controller.evaluateCloseMessage.bind(controller);

    controller.configure({ swipe: false });
    controller.state.openness.readyToOpen(true);
    controller.evaluateCloseMessage = () => {
      evaluatedSegments.push([...controller.currentSegment]);
      evaluateCloseMessage();
    };

    controller.close();
    controller.close();

    assert.deepEqual(
      evaluatedSegments,
      [
        [0, 0],
        [0, 0],
      ],
      "the toggled silent state handles one evaluation per request"
    );
    assert.true(
      controller.state.openness.isOpen,
      "a close request at the initial segment remains rejected"
    );

    controller.cleanup();
  });

  test("a rejected controlled close restores presented state", function (assert) {
    const controller = new Controller();
    const presentedChanges = [];

    controller.configure({ swipe: false });
    controller.state.openness.readyToOpen(true);
    controller.rootComponent = {
      effectivePresented: false,
      present() {
        presentedChanges.push(true);
      },
    };

    controller.close();

    assert.deepEqual(
      presentedChanges,
      [true],
      "the rejected close reconciles the controlled Root"
    );
    assert.true(
      controller.state.openness.isOpen,
      "the sheet remains open at a non-closeable boundary"
    );

    controller.cleanup();
  });

  test("defaults only undefined view options", function (assert) {
    const controller = new Controller();

    assert.strictEqual(
      controller.role,
      undefined,
      "the primitive sheet has no implicit role"
    );

    const nullableOptions = {
      inertOutside: null,
      nativeFocusScrollPrevention: null,
      pageScroll: null,
      role: null,
      snapOutAcceleration: null,
      snapToEndDetentsAcceleration: null,
      swipe: null,
      swipeDismissal: null,
      swipeOvershoot: null,
      swipeTrap: null,
    };

    controller.configure(nullableOptions);

    for (const [option, value] of Object.entries(nullableOptions)) {
      assert.strictEqual(
        controller[option],
        value,
        `${option} preserves an explicit null`
      );
    }

    controller.configure(
      Object.fromEntries(Object.keys(nullableOptions).map((option) => [option]))
    );

    for (const option of Object.keys(nullableOptions)) {
      assert.strictEqual(
        controller[option],
        Controller.OPTION_DEFAULTS[option],
        `${option} restores its default for undefined`
      );
    }

    controller.cleanup();
  });

  test("resolves swipe trap defaults by travel axis", function (assert) {
    let isAppleMobile = false;
    let isAndroidChromiumBrowser = false;
    sinon.stub(capabilities, "isAppleMobile").get(() => isAppleMobile);
    sinon
      .stub(capabilities, "isAndroidChromiumBrowser")
      .get(() => isAndroidChromiumBrowser);
    const controller = new Controller();

    assert.strictEqual(
      controller.resolvedSwipeTrap,
      "vertical",
      "an omitted trap defaults to the vertical travel axis"
    );

    controller.configure({ swipeTrap: null, tracks: "right" });
    assert.strictEqual(
      controller.resolvedSwipeTrap,
      "horizontal",
      "null uses the same horizontal-axis default as Silk"
    );

    controller.configure({ swipeTrap: { x: false, y: true } });
    assert.strictEqual(
      controller.resolvedSwipeTrap,
      "vertical",
      "an explicit axis object is preserved"
    );

    controller.configure({ swipeTrap: true });
    assert.strictEqual(
      controller.resolvedSwipeTrap,
      "both",
      "true traps both axes"
    );

    controller.configure({ swipeTrap: false });
    assert.strictEqual(
      controller.resolvedSwipeTrap,
      "none",
      "false traps neither axis"
    );

    controller.configure({ swipeTrap: undefined, tracks: "bottom" });
    isAndroidChromiumBrowser = true;
    assert.strictEqual(
      controller.resolvedSwipeTrap,
      "none",
      "Android Chromium disables the primary vertical trap"
    );

    isAndroidChromiumBrowser = false;
    isAppleMobile = true;
    controller.configure({ inertOutside: true, swipeTrap: false });
    assert.strictEqual(
      controller.resolvedSwipeTrap,
      "vertical",
      "an inert Apple sheet forces the vertical trap"
    );

    controller.cleanup();
  });

  test("reapplies dynamic inertOutside changes while presented", function (assert) {
    const updateInertOutside = sinon.spy();
    const controller = new Controller();

    controller.configure({
      inertOutside: false,
      sheetRegistry: { updateInertOutside },
    });
    assert.false(
      updateInertOutside.called,
      "configuration does not register an unpresented sheet"
    );

    controller.isPresented = true;
    controller.configure({ inertOutside: true });

    assert.true(
      updateInertOutside.calledOnceWithExactly(controller, true),
      "the active layer is updated when inertOutside changes"
    );

    controller.configure({ inertOutside: true });
    assert.strictEqual(
      updateInertOutside.callCount,
      1,
      "an unchanged value does not recalculate the layer"
    );

    controller.cleanup();
  });
});

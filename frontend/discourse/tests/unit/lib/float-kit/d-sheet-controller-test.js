import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import Controller from "discourse/float-kit/components/d-sheet/controller";
import DimensionCalculator from "discourse/float-kit/components/d-sheet/dimensions-calculator";
import { buildStateEffects } from "discourse/float-kit/components/d-sheet/state-effects";
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

function createStuckCorrectionController() {
  const controller = new Controller();

  controller.configure({
    detents: ["50vh"],
    swipeDismissal: false,
    swipeOvershoot: false,
  });
  controller.state.openness.readyToOpen(true);
  controller.currentSegment = [0, 1];

  return controller;
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

  test("synchronizes skip machines after animation settings render", function (assert) {
    const frames = stubAnimationFrames();
    const controller = new Controller();
    const enteringAnimationSettings = { skip: true };
    const exitingAnimationSettings = { skip: false };
    const syncSkipStates = sinon.spy(
      controller.animationTravel,
      "syncSkipStates"
    );

    controller.configure({
      enteringAnimationSettings,
      exitingAnimationSettings,
    });

    assert.false(
      syncSkipStates.called,
      "configuration does not update tracked state synchronously"
    );
    assert.strictEqual(frames.size, 1, "one configuration frame is queued");
    assert.true(
      controller.timeoutManager.tasks.has("configurationSkipStateSync"),
      "the deferred synchronization is controller-owned"
    );

    frames.flush();

    assert.true(
      controller.state.skip.isOpening,
      "entering skip is enabled from normalized settings"
    );
    assert.false(
      controller.state.skip.isClosing,
      "exiting skip is disabled from normalized settings"
    );

    controller.configure({
      enteringAnimationSettings,
      exitingAnimationSettings,
    });

    assert.strictEqual(
      frames.size,
      0,
      "unchanged configuration identities do not schedule a frame"
    );

    controller.configure({
      enteringAnimationSettings: { skip: false },
      exitingAnimationSettings: { skip: false },
    });
    controller.configure({
      enteringAnimationSettings: { skip: false },
      exitingAnimationSettings: { skip: true },
    });

    assert.strictEqual(
      frames.size,
      1,
      "dynamic configuration updates share one keyed frame"
    );

    frames.flush();

    assert.false(
      controller.state.skip.isOpening,
      "a dynamic entering setting disables opening skip"
    );
    assert.true(
      controller.state.skip.isClosing,
      "a dynamic exiting setting enables closing skip"
    );

    controller.configure({
      enteringAnimationSettings: { skip: true },
      exitingAnimationSettings: { skip: false },
    });

    controller.open();

    assert.false(
      controller.timeoutManager.tasks.has("configurationSkipStateSync"),
      "opening consumes the pending configuration immediately"
    );
    assert.true(
      controller.state.skip.isOpening,
      "opening uses the latest entering setting"
    );
    assert.false(
      controller.state.skip.isClosing,
      "opening also synchronizes the latest exiting setting"
    );

    controller.configure({
      enteringAnimationSettings: { skip: false },
      exitingAnimationSettings: { skip: true },
    });

    controller.close();

    assert.false(
      controller.timeoutManager.tasks.has("configurationSkipStateSync"),
      "closing consumes the pending configuration immediately"
    );
    assert.false(
      controller.state.skip.isOpening,
      "closing synchronizes the latest entering setting"
    );
    assert.true(
      controller.state.skip.isClosing,
      "closing uses the latest exiting setting"
    );

    controller.configure({
      enteringAnimationSettings: { skip: true },
      exitingAnimationSettings: { skip: false },
    });

    controller.cleanup();
    frames.flush();

    assert.strictEqual(frames.size, 0, "cleanup cancels the pending frame");
    assert.strictEqual(
      syncSkipStates.callCount,
      4,
      "cleanup prevents the final configuration sync"
    );
  });

  test("cancels deferred staging transitions during cleanup", function (assert) {
    const frames = stubAnimationFrames();
    const controller = new Controller();
    const readyToOpen = sinon.spy(controller.state.openness, "readyToOpen");
    const completeSkippedOpening = sinon.spy(
      controller,
      "completeSkippedOpening"
    );
    const effects = buildStateEffects(controller);

    effects
      .find(
        (effect) =>
          effect.machine === "staging" &&
          effect.state === "opening" &&
          effect.timing === "after-paint"
      )
      .callback();
    effects
      .find(
        (effect) =>
          effect.machine === "staging" &&
          effect.state === "open" &&
          effect.timing === "after-paint"
      )
      .callback();

    assert.strictEqual(frames.size, 2, "both readiness frames are queued");
    assert.true(
      controller.timeoutManager.tasks.has("stagingOpeningReady"),
      "the animated opening frame is managed"
    );
    assert.true(
      controller.timeoutManager.tasks.has("stagingOpenReady"),
      "the skipped opening frame is managed"
    );

    controller.cleanup();
    frames.flush();

    assert.strictEqual(frames.size, 0, "cleanup cancels both frames");
    assert.false(readyToOpen.called, "opening cannot advance after cleanup");
    assert.false(
      completeSkippedOpening.called,
      "skipped opening cannot advance after cleanup"
    );
  });

  test("cancels skipped closing completion during cleanup", function (assert) {
    const frames = stubAnimationFrames();
    const controller = new Controller();
    const opennessSend = sinon.spy(controller.state.openness, "send");
    const syncSkipStates = sinon.spy(
      controller.animationTravel,
      "syncSkipStates"
    );

    controller.handleClosingWithoutAnimation();

    assert.strictEqual(frames.size, 1, "closing completion is queued");
    assert.true(
      controller.timeoutManager.tasks.has("closingWithoutAnimation"),
      "the closing frame is managed"
    );

    controller.cleanup();
    frames.flush();

    assert.strictEqual(frames.size, 0, "cleanup cancels the closing frame");
    assert.false(
      opennessSend.called,
      "closing cannot transition after cleanup"
    );
    assert.false(
      syncSkipStates.called,
      "skip state is not synced after cleanup"
    );
  });

  test("staging reconciles the Root presentation state", function (assert) {
    const controller = new Controller();
    const presentedChanges = [];
    const rootComponent = {
      effectivePresented: false,
      present() {
        this.effectivePresented = true;
        presentedChanges.push(true);
      },
      dismiss() {
        this.effectivePresented = false;
        presentedChanges.push(false);
      },
    };

    controller.rootComponent = rootComponent;
    controller.state.staging.openPrepared();
    controller.state.openness.readyToOpen(false);

    rootComponent.effectivePresented = false;
    controller.close();

    rootComponent.effectivePresented = false;
    controller.state.openness.completeAnimation();

    assert.false(
      rootComponent.effectivePresented,
      "presentation is not reconciled without a staging entry"
    );

    rootComponent.effectivePresented = true;
    controller.state.staging.actuallyClose();

    assert.deepEqual(
      presentedChanges,
      [true, false],
      "staging entry presents while opening and dismisses while closing"
    );
    assert.true(
      controller.state.openness.isOpen,
      "a close request during opening does not interrupt the lifecycle"
    );

    controller.cleanup();
  });

  test("opening suppresses outside and Escape dismissal handlers", function (assert) {
    const store = this.owner.lookup("service:sheet-layer-store");
    const controller = new Controller();
    const outside = document.createElement("div");
    const clickOutside = sinon.spy();
    const escapeKeyDown = sinon.spy();
    const requestDismiss = sinon.spy();
    const preventDefault = sinon.spy();

    Object.defineProperty(controller, "requestDismiss", {
      configurable: true,
      value: requestDismiss,
    });
    controller.onClickOutside = clickOutside;
    controller.onEscapeKeyDown = escapeKeyDown;
    controller.state.openness.readyToOpen(false);
    document.body.append(outside);
    store.registerSheet(controller);

    try {
      store.consumeClickOutside({ target: outside });
      store.consumeEscapeKey({ preventDefault });

      assert.false(
        controller.canAcceptDismissRequest,
        "an opening sheet does not accept ambient dismissal"
      );
      assert.false(clickOutside.called, "click-outside callback is suppressed");
      assert.false(escapeKeyDown.called, "Escape callback is suppressed");
      assert.false(requestDismiss.called, "no dismissal is requested");
      assert.false(preventDefault.called, "Escape remains unconsumed");
    } finally {
      store.unregisterSheet(controller);
      outside.remove();
      controller.cleanup();
    }
  });

  test("derives dismissal-disabled swipe behavior with Silk's WebKit spacer rule", function (assert) {
    sinon.stub(Controller, "browserSupportsRequiredFeatures").get(() => true);
    sinon.stub(capabilities, "browserEngine").value("webkit");

    const sheetWithoutDetents = new Controller();
    sheetWithoutDetents.configure({
      swipeDismissal: false,
      swipeOvershoot: true,
    });
    sheetWithoutDetents.state.openness.readyToOpen(true);

    assert.false(
      sheetWithoutDetents.swipeDisabled,
      "WebKit keeps swipe enabled when the small spacer can prevent dismissal"
    );
    assert.true(
      sheetWithoutDetents.webkitSmallSpacerMode,
      "the small-spacer coordinate system is enabled"
    );
    assert.false(
      sheetWithoutDetents.swipeOutDisabledWithDetent,
      "the detent-specific restriction stays disabled without detents"
    );

    const sheetWithDetents = new Controller();
    sheetWithDetents.configure({
      detents: ["50vh"],
      swipeDismissal: false,
      swipeOvershoot: true,
    });
    sheetWithDetents.state.openness.readyToOpen(true);

    assert.false(sheetWithDetents.swipeDisabled, "detent swipe stays enabled");
    assert.false(
      sheetWithDetents.webkitSmallSpacerMode,
      "detents use their own dismissal boundary"
    );
    assert.true(
      sheetWithDetents.swipeOutDisabledWithDetent,
      "swipe-out is constrained at the first detent"
    );

    sheetWithoutDetents.cleanup();
    sheetWithDetents.cleanup();
  });

  test("explicit null disables swipe", function (assert) {
    sinon.stub(Controller, "browserSupportsRequiredFeatures").get(() => true);

    const controller = new Controller();

    controller.configure({ swipe: null });
    controller.state.openness.readyToOpen(true);

    assert.true(
      controller.swipeDisabled,
      "a falsy explicit swipe option disables interaction while presented"
    );

    controller.cleanup();
  });

  test("geometry invalidation resets resize observation delivery", function (assert) {
    const controller = new Controller();

    sinon.spy(controller.observerManager, "resetResizeObservationCycle");
    controller.configure({ tracks: "top" });

    assert.true(
      controller.observerManager.resetResizeObservationCycle.calledOnce,
      "one configuration transaction restarts first-delivery handling once"
    );

    controller.configure({ tracks: "top" });

    assert.strictEqual(
      controller.observerManager.resetResizeObservationCycle.callCount,
      1,
      "an unchanged geometry option keeps the current observation cycle"
    );

    controller.cleanup();
  });

  test("resize remaps the resting segment to the nearest physical detent", function (assert) {
    const controller = new Controller();
    const newDimensions = {
      content: { travelAxis: { unitless: 100 } },
      exactProgressValueAtDetents: [0, 0.6, 0.95],
      progressValueAtDetents: [{ exact: 0 }, { exact: 0.6 }, { exact: 0.95 }],
    };

    sinon
      .stub(DimensionCalculator.prototype, "calculateDimensions")
      .returns(newDimensions);
    sinon.stub(controller.animationTravel, "recalculateAndTravel");

    controller.configure({ swipe: false });
    controller.view = document.createElement("div");
    controller.content = document.createElement("div");
    controller.scrollContainer = document.createElement("div");
    controller.dimensions = {
      content: { travelAxis: { unitless: 100 } },
      exactProgressValueAtDetents: [0, 0.2, 0.55],
      progressValueAtDetents: [{ exact: 0 }, { exact: 0.2 }, { exact: 0.55 }],
    };
    controller.activeDetent = 2;
    controller.currentSegment = [2, 2];
    controller.targetDetent = 2;
    controller.state.openness.readyToOpen(true);

    controller.recalculateDimensionsFromResize();

    assert.deepEqual(
      controller.currentSegment,
      [1, 1],
      "the resized geometry wins over the previous detent index"
    );
    assert.strictEqual(
      controller.targetDetent,
      2,
      "resize remapping preserves the configured opening detent"
    );
    assert.strictEqual(
      controller.lastProcessedProgress,
      0.6,
      "progress is synchronized to the remapped detent"
    );
    assert.true(
      controller.animationTravel.recalculateAndTravel.calledOnceWithExactly(1),
      "the correction travels to the remapped index"
    );

    controller.cleanup();
  });

  test("clears persisted outlet styles when long-running work ends", async function (assert) {
    const controller = new Controller();
    const target = document.createElement("div");
    let restoreCount = 0;

    target.style.transform = "scale(0.9)";
    target.style.transformOrigin = "0 50%";
    controller.registerStackingAnimation({
      target,
      restorePersistedStyles() {
        restoreCount++;
        target.style.transform = "rotate(5deg)";
      },
    });

    controller.state.longRunning.start();
    controller.state.longRunning.end();
    await settled();

    assert.strictEqual(
      target.style.transform,
      "rotate(5deg)",
      "the lifecycle delegates restoration to the animation owner"
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
      "rotate(5deg)",
      "controller destruction delegates restoration to the animation owner"
    );
    assert.strictEqual(
      restoreCount,
      2,
      "each lifecycle boundary requests one ownership-aware restoration"
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

  test("animated opening publishes progress zero before starting travel", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const calls = [];
    const controller = new Controller();

    controller.configure({
      onTravel: ({ progress, range }) =>
        calls.push(`travel:${progress}:${range.start}-${range.end}`),
      onTravelStart: () => calls.push("start"),
    });
    controller.travelAnimations.push({
      callback: (progress) => calls.push(`animation:${progress}`),
    });
    sinon
      .stub(controller.stackingAdapter, "notifyBelowSheets")
      .callsFake((progress) => calls.push(`below:${progress}`));

    controller.state.staging.openPrepared();
    await settled();

    assert.deepEqual(
      calls,
      ["start", "travel:0:0-0", "animation:0", "below:0"],
      "the full zero-progress callback runs before the opening frame"
    );

    const travel = sinon.stub(controller.animationTravel, "animateToDetent");
    controller.startOpeningAnimation();

    assert.false(
      travel.lastCall.args[3],
      "opening travel suppresses a duplicate onTravelStart"
    );

    controller.cleanup();
    animationFrames.flush();
  });

  test("travel status callbacks use Silk's public vocabulary", function (assert) {
    const statuses = [];
    const controller = new Controller();

    controller.configure({
      onTravelStatusChange: (status) => statuses.push(status),
    });
    sinon.stub(controller.animationTravel, "animateToDetent");

    controller.handleOpening();
    controller.updateTravelStatus("idleInside");
    controller.handleStepMessage({ detent: 1 });
    controller.updateTravelStatus("idleInside");
    controller.handleClosing();
    controller.updateTravelStatus("idleOutside");

    assert.deepEqual(
      statuses,
      [
        "entering",
        "idleInside",
        "stepping",
        "idleInside",
        "exiting",
        "idleOutside",
      ],
      "open, step, and close expose Silk's exact statuses"
    );

    controller.cleanup();
  });

  module("manual scroll parity", function () {
    test("programmatic scroll refreshes the end debounce without starting manual state", function (assert) {
      const controller = new Controller();

      controller.state.openness.readyToOpen(true);
      controller.scrollContainer = {};
      controller.dimensions = { progressValueAtDetents: [] };
      const scheduleScrollEnd = sinon.stub(
        controller.timeoutManager,
        "schedule"
      );

      controller.markProgrammaticScroll();
      controller.handleScrollStateChange();

      assert.false(
        controller.state.openness.isScrollOngoing,
        "the sentinel suppresses a manual scroll start"
      );
      assert.false(
        controller.state.openness.isSwipeOngoing,
        "the sentinel suppresses a manual swipe start"
      );
      assert.true(
        scheduleScrollEnd.calledOnce,
        "the latest scroll event still owns the end debounce"
      );
      assert.strictEqual(
        scheduleScrollEnd.firstCall.args[0],
        "scrollEnd",
        "the scroll-end task is replaced"
      );
      assert.strictEqual(
        scheduleScrollEnd.firstCall.args[2],
        200,
        "the native scroll quiet period is preserved"
      );

      controller.cleanup();
    });

    test("scroll events remain active while a detent step is staged", function (assert) {
      const controller = new Controller();

      controller.state.openness.readyToOpen(true);
      controller.scrollContainer = {};
      controller.dimensions = {
        progressValueAtDetents: [{ exact: 0 }, { exact: 1 }],
      };
      sinon.stub(controller.state.staging, "current").get(() => "stepping");
      sinon.stub(controller.timeoutManager, "schedule");

      controller.handleScrollStateChange();

      assert.true(
        controller.state.openness.isScrollOngoing,
        "the open scroll machine receives the event"
      );
      assert.true(
        controller.state.openness.isSwipeOngoing,
        "manual swipe state is not gated by staging"
      );
      assert.true(
        controller.state.openness.isMoveOngoing,
        "manual move state is not gated by staging"
      );

      controller.cleanup();
    });

    test("native scroll progress travels before swipe-out", function (assert) {
      const controller = new Controller();
      const travelProgress = [];

      controller.configure({
        onTravel: ({ progress }) => travelProgress.push(progress),
      });
      controller.state.openness.readyToOpen(true);
      controller.scrollContainer = { scrollTop: 110 };
      controller.dimensions = {
        content: { travelAxis: { unitless: 100 } },
        scroll: { travelAxis: { unitless: 200 } },
        snapOutAccelerator: { travelAxis: { unitless: 10 } },
        exactProgressValueAtDetents: [0, 1],
        progressValueAtDetents: [
          { before: -0.01, exact: 0, after: 0.01 },
          { before: 0.99, exact: 1, after: 1.01 },
        ],
      };
      sinon.stub(controller.timeoutManager, "schedule");

      controller.handleScrollStateChange();
      controller.processScrollFrame();
      controller.scrollContainer.scrollTop = 60;
      controller.handleScrollStateChange();
      controller.processScrollFrame();

      assert.deepEqual(
        travelProgress,
        [1, 0.5],
        "native scroll positions publish their travel progress"
      );
      assert.true(
        controller.state.openness.isOpen,
        "pre-threshold scrolling leaves swipe-out to the intersection observer"
      );

      controller.cleanup();
    });

    test("scroll end resolves from the last processed progress", function (assert) {
      const controller = new Controller();
      let finishScroll;

      controller.state.openness.readyToOpen(true);
      controller.scrollContainer = {};
      controller.dimensions = {
        progressValueAtDetents: [{ exact: 0 }, { exact: 0.5 }, { exact: 1 }],
      };
      controller.lastProcessedProgress = 0.5;
      const calculateProgress = sinon
        .stub(controller.scrollProgressCalculator, "calculateProgress")
        .returns({ clampedProgress: 0.8 });
      sinon
        .stub(controller.timeoutManager, "schedule")
        .callsFake((_key, callback) => (finishScroll = callback));

      controller.handleScrollStateChange();
      finishScroll();

      assert.false(
        calculateProgress.called,
        "the end handler does not take a second unsmoothed sample"
      );
      assert.true(
        controller.state.openness.isScrollEnded,
        "the processed detent progress ends scrolling"
      );
      assert.false(
        controller.state.openness.isSwipeOngoing,
        "the matching processed progress ends the swipe"
      );
      assert.false(
        controller.state.openness.isMoveOngoing,
        "the quiet period always ends movement"
      );

      controller.cleanup();
    });

    test("manual progress publishes before sharing one tween with outlets", function (assert) {
      const calls = [];
      const tweens = [];
      const controller = new Controller();

      controller.dimensions = {
        exactProgressValueAtDetents: [0, 0.5, 1],
        progressValueAtDetents: [
          { before: -0.01, exact: 0, after: 0.01 },
          { before: 0.49, exact: 0.5, after: 0.51 },
          { before: 0.99, exact: 1, after: 1.01 },
        ],
      };
      controller.configure({
        onTravel: () => calls.push("travel"),
      });
      controller.travelAnimations.push(
        {
          callback(_progress, tween) {
            calls.push("outlet:first");
            tweens.push(tween);
          },
        },
        {
          callback(_progress, tween) {
            calls.push("outlet:second");
            tweens.push(tween);
          },
        }
      );
      sinon
        .stub(controller.stackingAdapter, "notifyBelowSheets")
        .callsFake(() => calls.push("below"));
      sinon
        .stub(controller.scrollProgressCalculator, "calculateProgress")
        .returns({ clampedProgress: 0.75 });
      controller.state.openness.readyToOpen(true);
      controller.state.openness.moveStart();

      controller.processScrollProgress();

      assert.deepEqual(
        calls,
        ["travel", "outlet:first", "outlet:second", "below"],
        "public travel runs before this sheet and sheets below"
      );
      assert.strictEqual(
        typeof tweens[0],
        "function",
        "outlets receive a tween"
      );
      assert.strictEqual(
        tweens[1],
        tweens[0],
        "all outlets share the frame's tween function"
      );

      controller.cleanup();
    });

    test("WebKit small-spacer progress uses the directional correction only", function (assert) {
      const transforms = {
        bottom: "translateY(-2px)",
        horizontal: "translateX(-2px)",
        left: "translateX(2px)",
        right: "translateX(-2px)",
        top: "translateY(2px)",
        vertical: "translateY(-2px)",
      };

      sinon.stub(Controller.prototype, "webkitSmallSpacerMode").get(() => true);

      for (const [track, expectedTransform] of Object.entries(transforms)) {
        const callbacks = [];
        const controller = new Controller();

        controller.tracks = track;
        controller.contentWrapper = document.createElement("div");
        controller.dimensions = {
          exactProgressValueAtDetents: [0, 1],
          progressValueAtDetents: [
            { before: -0.01, exact: 0, after: 0.01 },
            { before: 0.99, exact: 1, after: 1.01 },
          ],
        };
        controller.configure({
          onTravel: () => callbacks.push("travel"),
        });
        controller.travelAnimations.push({
          callback: () => callbacks.push("outlet"),
        });
        sinon
          .stub(controller.stackingAdapter, "notifyBelowSheets")
          .callsFake(() => callbacks.push("below"));
        const calculateProgress = sinon
          .stub(controller.scrollProgressCalculator, "calculateProgress")
          .returns({ clampedProgress: 0.5 });
        controller.state.openness.readyToOpen(true);
        controller.state.openness.moveStart();

        controller.processScrollProgress();

        assert.strictEqual(
          controller.contentWrapper.style.transform,
          expectedTransform,
          `${track} uses its exact small-spacer correction`
        );
        assert.deepEqual(
          callbacks,
          [],
          `${track} suppresses the normal travel callback pipeline`
        );

        calculateProgress.returns({ clampedProgress: 0 });
        controller.processScrollProgress();

        assert.strictEqual(
          controller.contentWrapper.style.transform,
          "",
          `${track} removes the correction at progress zero`
        );

        controller.cleanup();
      }
    });

    test("WebKit small-spacer correction is restored on mode exit and cleanup", function (assert) {
      let smallSpacerMode = true;
      const controller = new Controller();

      sinon
        .stub(controller, "webkitSmallSpacerMode")
        .get(() => smallSpacerMode);
      controller.contentWrapper = document.createElement("div");
      controller.dimensions = {
        progressValueAtDetents: [
          { before: -0.01, exact: 0, after: 0.01 },
          { before: 0.99, exact: 1, after: 1.01 },
        ],
      };
      sinon
        .stub(controller.scrollProgressCalculator, "calculateProgress")
        .returns({ clampedProgress: 0.5 });
      controller.state.openness.readyToOpen(true);
      controller.state.openness.moveStart();

      controller.processScrollProgress();
      assert.strictEqual(
        controller.contentWrapper.style.transform,
        "translateY(-2px)",
        "small-spacer mode owns the correction"
      );

      smallSpacerMode = false;
      controller.processScrollProgress();
      assert.strictEqual(
        controller.contentWrapper.style.transform,
        "",
        "leaving the mode restores the content wrapper"
      );

      smallSpacerMode = true;
      controller.lastProcessedProgress = null;
      controller.processScrollProgress();
      const contentWrapper = controller.contentWrapper;
      controller.cleanup();

      assert.strictEqual(
        contentWrapper.style.transform,
        "",
        "controller cleanup restores its owned transform"
      );
    });

    test("scroll smoothing starts from processed progress or the segment end", function (assert) {
      const processedController = new Controller();

      processedController.state.openness.readyToOpen(true);
      processedController.dimensions = {
        progressValueAtDetents: [{ exact: 0 }, { exact: 0.4 }, { exact: 0.9 }],
      };
      processedController.activeDetent = 1;
      processedController.currentSegment = [1, 2];
      processedController.lastProcessedProgress = 0.72;
      const processedSmoother = sinon
        .stub(processedController, "createProgressSmoother")
        .returns((progress) => progress);

      processedController.state.openness.scrollStart();

      assert.true(
        processedSmoother.calledOnceWithExactly(0.72),
        "the prior processed frame continues smoothly"
      );

      const segmentController = new Controller();

      segmentController.state.openness.readyToOpen(true);
      segmentController.dimensions = {
        progressValueAtDetents: [{ exact: 0 }, { exact: 0.4 }, { exact: 0.9 }],
      };
      segmentController.activeDetent = 1;
      segmentController.currentSegment = [1, 2];
      const segmentSmoother = sinon
        .stub(segmentController, "createProgressSmoother")
        .returns((progress) => progress);

      segmentController.state.openness.scrollStart();

      assert.true(
        segmentSmoother.calledOnceWithExactly(0.9),
        "the segment end seeds a gesture without processed history"
      );

      processedController.cleanup();
      segmentController.cleanup();
    });

    test("leaving open clears the pending scroll-end task", function (assert) {
      const controller = new Controller();

      controller.state.openness.readyToOpen(true);
      controller.timeoutManager.scheduleNative("scrollEnd", () => {}, 10_000);

      assert.true(
        controller.timeoutManager.tasks.has("scrollEnd"),
        "the debounce is pending while open"
      );

      controller.state.openness.send(EVENTS.SWIPED_OUT);

      assert.false(
        controller.timeoutManager.tasks.has("scrollEnd"),
        "the open-state cleanup cancels the debounce"
      );

      controller.cleanup();
    });
  });

  test("steps wait for scroll-end paint and cannot overlap", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const controller = new Controller();

    controller.detents = ["25vh", "50vh"];
    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];
    controller.state.openness.readyToOpen(true);
    await flushAnimationFrames(animationFrames);

    assert.true(
      controller.state.openness.areScrollEndedAfterPaintEffectsRun,
      "the initial open state becomes ready after paint"
    );

    const travel = sinon.stub(controller, "handleStepMessage");

    controller.state.openness.scrollStart();
    controller.stepToDetent(2);
    controller.stepToDetent(3);

    assert.false(
      controller.state.openness.areScrollEndedAfterPaintEffectsRun,
      "starting native scroll resets step readiness"
    );
    assert.true(
      controller.state.staging.isNone,
      "no staging transition fights the native scroll"
    );
    assert.false(
      travel.called,
      "no programmatic travel starts while scrolling"
    );

    controller.state.openness.scrollEnd();
    await flushAnimationFrames(animationFrames);

    assert.true(controller.state.staging.isStepping, "the queued step starts");
    assert.true(
      travel.calledOnceWith(sinon.match({ detent: 3 })),
      "only the latest queued request travels after paint"
    );

    controller.stepToDetent(2);
    await flushAnimationFrames(animationFrames);

    assert.strictEqual(
      travel.callCount,
      1,
      "staging rejects a second travel while already stepping"
    );

    controller.cleanup();
  });

  test("wheel scrolling corrects a newly stuck end immediately", function (assert) {
    const controller = createStuckCorrectionController();
    const correction = sinon.stub(controller, "stepToStuckPosition");

    controller.state.openness.scrollStart();
    controller.setSegment([1, 1]);

    assert.true(
      correction.calledOnceWithExactly("back"),
      "touch-ended wheel input does not wait for scroll-end debounce"
    );

    controller.cleanup();
  });

  test("touch scrolling corrects a stuck end after 80ms and a frame", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const controller = createStuckCorrectionController();
    const correction = sinon.stub(controller, "stepToStuckPosition");

    await flushAnimationFrames(animationFrames);

    const clock = sinon.useFakeTimers({
      toFake: ["setTimeout", "clearTimeout"],
    });

    controller.handleTouchStart();
    controller.state.openness.scrollStart();
    controller.setSegment([1, 1]);

    assert.false(
      correction.called,
      "correction waits while the touch remains active"
    );

    controller.handleTouchEnd();
    clock.tick(80);

    assert.false(correction.called, "the timeout preserves the frame boundary");
    assert.strictEqual(
      animationFrames.size,
      1,
      "one correction frame is owned"
    );

    animationFrames.flush();

    assert.true(
      correction.calledOnceWithExactly("back"),
      "the current stuck end is corrected on the next frame"
    );

    controller.cleanup();
  });

  test("touch end without scrolling neither schedules nor leaks correction", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const controller = createStuckCorrectionController();
    const correction = sinon.stub(controller, "stepToStuckPosition");

    await flushAnimationFrames(animationFrames);

    const clock = sinon.useFakeTimers({
      toFake: ["setTimeout", "clearTimeout"],
    });

    controller.state.stuck.startBack();
    controller.handleTouchStart();
    controller.handleTouchEnd();
    clock.tick(80);

    assert.strictEqual(animationFrames.size, 0, "a tap schedules no frame");
    assert.false(correction.called, "a tap performs no correction");

    controller.markScrollOccurred();
    controller.handleTouchEnded();
    clock.tick(80);

    assert.strictEqual(
      animationFrames.size,
      1,
      "a scrolled touch owns its frame"
    );

    controller.cleanup();

    assert.strictEqual(
      animationFrames.size,
      0,
      "controller cleanup cancels the owned correction frame"
    );
    animationFrames.flush();
    assert.false(correction.called, "the cancelled frame cannot travel");
  });

  test("stuck correction applies the overflow workaround only on WebKit", function (assert) {
    let isWebKit = false;
    const controller = new Controller();
    const travel = sinon.stub(
      controller.animationTravel,
      "stepToStuckPosition"
    );
    const hideOverflow = sinon.stub(
      controller.domAttributes,
      "temporarilyHideOverflow"
    );

    sinon.stub(capabilities, "isWebKit").get(() => isWebKit);

    controller.stepToStuckPosition("back");
    assert.false(hideOverflow.called, "other engines retain native overflow");

    isWebKit = true;
    controller.stepToStuckPosition("front");

    assert.true(
      travel.calledTwice,
      "both engines perform the silent position correction"
    );
    assert.true(
      hideOverflow.calledOnce,
      "only WebKit receives the temporary overflow workaround"
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

  test("reports active detents at each accepted close stage", async function (assert) {
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

    assert.strictEqual(
      calls.length,
      2,
      "dismissal and the queued manual rest each report once"
    );
    assert.true(
      calls.every((detent) => detent === 0),
      "each accepted close stage reports the dismissed detent"
    );

    controller.handleStateTransition({ type: EVENTS.READY_TO_CLOSE });

    assert.strictEqual(
      calls.length,
      3,
      "closing travel reports its programmatic target"
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

  test("releases programmatic detent suppression at the destination segment", async function (assert) {
    const controller = new Controller();
    const calls = [];

    controller.configure({
      onActiveDetentChange: (detent) => calls.push(`active:${detent}`),
      onTravel: () => calls.push("travel"),
      onTravelRangeChange: ({ start, end }) =>
        calls.push(`range:${start}-${end}`),
      swipe: false,
    });
    controller.animationTravel.animateToDetent = (detent) => {
      controller.setSegment([detent, detent]);
      controller.notifyTravel(detent);
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
      ["active:1", "travel", "range:1-1"],
      "the queued destination segment consumes the immediate notification"
    );

    controller.setSegment([0, 1]);
    controller.setSegment([0, 0]);
    await Promise.resolve();

    assert.deepEqual(
      calls.slice(-3),
      ["range:0-1", "range:0-0", "active:0"],
      "manual resting changes notify before the travel lifecycle completes"
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

  test("a no-dimension travel retains suppression until its destination settles", async function (assert) {
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
      [1],
      "the destination rest consumes the immediate notification"
    );

    controller.setSegment([0, 1]);
    controller.setSegment([0, 0]);
    await Promise.resolve();

    assert.deepEqual(calls, [1, 0], "later manual resting changes notify");

    controller.cleanup();
  });

  test("resolves opening detents from integer configuration", function (assert) {
    const controller = new Controller();

    controller.configure({
      activeDetent: 3,
      defaultActiveDetent: 2,
    });
    assert.strictEqual(
      controller.targetDetent,
      2,
      "an integer default takes precedence"
    );

    controller.configure({
      activeDetent: 4,
      defaultActiveDetent: undefined,
    });
    assert.strictEqual(
      controller.targetDetent,
      4,
      "a positive integer controlled value is used without a default"
    );

    controller.configure({ activeDetent: null });
    assert.strictEqual(
      controller.targetDetent,
      3,
      "an invalid controlled value falls back to its initial valid value"
    );

    controller.configure({ activeDetent: 2.5 });
    assert.strictEqual(
      controller.targetDetent,
      3,
      "a fractional controlled value is not an animation destination"
    );

    const controllerWithoutInitialDetent = new Controller();
    controllerWithoutInitialDetent.configure({ activeDetent: undefined });
    controllerWithoutInitialDetent.configure({ activeDetent: 2 });
    assert.strictEqual(
      controllerWithoutInitialDetent.targetDetent,
      2,
      "a later positive integer controlled value is accepted"
    );

    controllerWithoutInitialDetent.configure({ activeDetent: "2" });
    assert.strictEqual(
      controllerWithoutInitialDetent.targetDetent,
      1,
      "an invalid value falls back to one without an initial valid value"
    );

    controllerWithoutInitialDetent.configure({
      activeDetent: 2,
      defaultActiveDetent: 0,
    });
    assert.strictEqual(
      controllerWithoutInitialDetent.targetDetent,
      0,
      "integer defaults accept zero"
    );

    controller.cleanup();
    controllerWithoutInitialDetent.cleanup();
  });

  test("controlled detent echoes do not repeat an in-flight step", function (assert) {
    const changes = [];
    const controller = new Controller();

    controller.configure({
      detents: ["40vh", "70vh"],
      onActiveDetentChange: (detent) => {
        changes.push(detent);
        controller.configure({ activeDetent: detent });
      },
      swipe: false,
    });
    controller.state.openness.readyToOpen(true);
    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];
    controller.travelRange = { start: 1, end: 1 };
    controller.targetDetent = 1;

    sinon.stub(controller.animationTravel, "animateToDetent");
    const transition = sinon.stub(controller, "handleStateTransition");

    assert.true(controller.state.openness.isOpen, "the sheet is open");
    assert.true(
      controller.detentManager.isValidDetent(2),
      "the requested detent would otherwise be accepted"
    );

    controller.handleStepMessage({ detent: 2 });

    assert.deepEqual(changes, [2], "the requested detent reports immediately");
    assert.false(
      transition.called,
      "echoing the controlled value does not enqueue the same step"
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
    const swipeReset = sinon.spy(controller.state.openness, "swipeReset");

    controller.state.openness.send(EVENTS.SWIPED_OUT);

    assert.strictEqual(
      cleanupCount,
      1,
      "the open-state exit releases its observer and wheel listeners"
    );
    assert.true(
      swipeReset.calledOnce,
      "the closed-pending lifecycle resets the completed swipe state"
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

  test("autofocus skips a nested scroll container", function (assert) {
    const controller = new Controller();
    const view = document.createElement("div");
    const scrollContainer = document.createElement("div");
    const button = document.createElement("button");

    scrollContainer.dataset.dScroll = "scroll-container";
    scrollContainer.tabIndex = 0;
    button.type = "button";
    sinon.stub(scrollContainer, "getClientRects").returns([{}]);
    sinon.stub(button, "getClientRects").returns([{}]);
    view.append(scrollContainer, button);
    controller.view = view;

    assert.strictEqual(
      controller.focusManagement.findAutoFocusTarget(),
      button,
      "the first actionable control wins over the scroll region"
    );

    controller.cleanup();
  });

  test("normalized detents keep stable identity until configuration changes", function (assert) {
    const controller = new Controller();
    const initialDetents = controller.detents;

    assert.strictEqual(
      controller.detents,
      initialDetents,
      "repeated reads reuse the normalized detents"
    );

    controller.detents = ["50vh"];

    assert.notStrictEqual(
      controller.detents,
      initialDetents,
      "a new detent configuration invalidates the cached normalization"
    );
    assert.deepEqual(
      controller.detents,
      ["50vh", "var(--d-sheet-content-travel-axis)"],
      "the invalidated value retains Silk's content-size detent"
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

  test("treats an empty detents string as absent", function (assert) {
    const controller = new Controller();

    controller.configure({ detents: "" });

    assert.deepEqual(
      controller.detents,
      ["var(--d-sheet-content-travel-axis)"],
      "an empty string keeps only the content detent"
    );

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

    controller.configure({
      sheetRegistry: {
        findContainingSheet() {
          return { resolvedSwipeTrap: "vertical" };
        },
      },
    });
    assert.strictEqual(
      controller.resolvedSwipeTrap,
      "none",
      "an ancestor Y-axis trap suppresses the nested Apple fallback"
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

import { module, test } from "qunit";
import sinon from "sinon";
import AnimationTravel from "discourse/float-kit/components/d-sheet/animation-travel";
import Controller from "discourse/float-kit/components/d-sheet/controller";
import DimensionCalculator from "discourse/float-kit/components/d-sheet/dimensions-calculator";

function dimensions() {
  return {
    content: { travelAxis: { unitless: 60 } },
    detentMarkers: [
      {
        accumulatedOffsets: { travelAxis: { unitless: 60 } },
        travelAxis: { unitless: 60 },
      },
    ],
    exactProgressValueAtDetents: [0, 1],
    progressValueAtDetents: [{ exact: 0 }, { exact: 1 }],
    snapOutAccelerator: { travelAxis: { unitless: 10 } },
    swipeOutDisabledWithDetent: false,
    view: { travelAxis: { unitless: 100 } },
  };
}

function multiDetentDimensions() {
  return {
    content: { travelAxis: { unitless: 60 } },
    detentMarkers: [
      {
        accumulatedOffsets: { travelAxis: { unitless: 30 } },
        travelAxis: { unitless: 30 },
      },
      {
        accumulatedOffsets: { travelAxis: { unitless: 60 } },
        travelAxis: { unitless: 30 },
      },
    ],
    exactProgressValueAtDetents: [0, 0.5, 1],
    progressValueAtDetents: [{ exact: 0 }, { exact: 0.5 }, { exact: 1 }],
    snapOutAccelerator: { travelAxis: { unitless: 10 } },
    swipeOutDisabledWithDetent: false,
    view: { travelAxis: { unitless: 100 } },
  };
}

function stubAnimationFrameQueue() {
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

function prepareController({ tracks, animationSettings, settingsKey }, calls) {
  const controller = new Controller();
  const scrollContainer = {
    scrollHeight: 10000,
    scrollLeft: 0,
    scrollTop: 0,
    scrollWidth: 10000,
    scrollTo(left, top) {
      calls.push(["scroll", left, top]);
      this.scrollLeft = left;
      this.scrollTop = top;
    },
  };

  controller.tracks = tracks;
  controller.contentPlacement = tracks;
  controller[settingsKey] = animationSettings;
  controller.view = document.createElement("div");
  controller.content = document.createElement("div");
  controller.scrollContainer = scrollContainer;
  controller.detentMarkers[0] = { isConnected: true };

  sinon
    .stub(DimensionCalculator.prototype, "calculateDimensions")
    .callsFake((track) => {
      calls.push(["measure", track]);
      return dimensions();
    });

  controller.recalculateDimensionsFromResize();
  calls.length = 0;

  return { controller, scrollContainer };
}

module("Unit | Lib | float-kit | animation-travel", function (hooks) {
  hooks.afterEach(function () {
    sinon.restore();
  });

  test("idle animation track updates do not invalidate dimensions", function (assert) {
    const calls = [];
    const { controller } = prepareController(
      {
        animationSettings: null,
        settingsKey: "enteringAnimationSettings",
        tracks: "bottom",
      },
      calls
    );
    const initialDimensions = controller.dimensions;

    controller.configure({
      enteringAnimationSettings: { track: "top" },
    });

    assert.strictEqual(
      controller.dimensions,
      initialDimensions,
      "an unchanged effective track keeps its measured dimensions"
    );
    assert.strictEqual(
      controller.tracks,
      "bottom",
      "the animation edge is not promoted outside staging"
    );

    controller.cleanup();
  });

  test("an opposite entering track is rendered and measured before travel", function (assert) {
    const calls = [];
    const { controller, scrollContainer } = prepareController(
      {
        animationSettings: { track: "top" },
        settingsKey: "enteringAnimationSettings",
        tracks: "bottom",
      },
      calls
    );

    controller.state.staging.openPrepared();
    sinon.stub(controller, "resetViewStyles");
    sinon.stub(controller.domAttributes, "setHidden");
    sinon
      .stub(controller.animationTravel, "animateToDetent")
      .callsFake((detent) => calls.push(["travel", detent]));

    controller.startOpeningAnimation();

    assert.strictEqual(
      controller.tracks,
      "vertical",
      "the staged layout exposes both vertical tracks"
    );
    assert.deepEqual(
      calls,
      [
        ["measure", "vertical"],
        ["travel", 1],
      ],
      "the promoted layout is measured before entering travel"
    );
    assert.strictEqual(
      scrollContainer.scrollTop,
      scrollContainer.scrollHeight,
      "the sheet is staged on the configured top edge"
    );

    controller.cleanup();
  });

  test("an opposite exiting track uses two-sided travel and restores the base track", function (assert) {
    const calls = [];
    const { controller, scrollContainer } = prepareController(
      {
        animationSettings: { skip: true, track: "left" },
        settingsKey: "exitingAnimationSettings",
        tracks: "right",
      },
      calls
    );

    controller.contentWrapper = document.createElement("div");
    controller.state.staging.actuallyClose();
    sinon.stub(controller.domAttributes, "disableScrollSnap");
    controller.onTravelEnd = () => calls.push(["end"]);
    sinon
      .stub(controller.stackingAdapter, "updateTravelProgress")
      .callsFake((progress) => calls.push(["stack", progress]));

    controller.handleClosing();

    assert.deepEqual(
      calls,
      [["measure", "horizontal"], ["scroll", 10000, 0], ["end"], ["stack", 0]],
      "travel ends publicly before the final stacking update"
    );
    assert.strictEqual(
      scrollContainer.scrollLeft,
      10000,
      "the opposite closed position uses the two-sided scroll range"
    );
    assert.strictEqual(
      controller.tracks,
      "right",
      "the configured track is restored when staging ends"
    );

    controller.cleanup();
  });

  test("stepping uses the base track", function (assert) {
    const controller = new Controller();
    const scrollContainer = {
      scrollLeft: 0,
      scrollTop: 0,
      scrollTo(left, top) {
        this.scrollLeft = left;
        this.scrollTop = top;
      },
    };

    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];
    controller.tracks = "bottom";
    controller.contentPlacement = "bottom";
    controller.enteringAnimationSettings = { track: "top" };
    controller.steppingAnimationSettings = { track: "top" };
    controller.view = document.createElement("div");
    controller.contentWrapper = document.createElement("div");
    controller.scrollContainer = scrollContainer;
    controller.dimensions = multiDetentDimensions();

    controller.animationTravel.animateToDetent(2, { skip: true });

    assert.strictEqual(
      scrollContainer.scrollTop,
      10000,
      "the stepping animation ignores animation tracks and travels on the bottom track"
    );

    controller.cleanup();
  });

  test("travel state advances before the public end callback", function (assert) {
    const calls = [];
    const controller = {
      activeDetent: 0,
      belowSheetsInStack: [],
      contentPlacement: "bottom",
      contentWrapper: document.createElement("div"),
      currentSegment: [0, 0],
      dimensions: dimensions(),
      enteringAnimationSettings: null,
      exitingAnimationSettings: null,
      scheduleTrackDimensionRecalculation() {},
      scrollContainer: {
        scrollLeft: 0,
        scrollTop: 0,
        scrollTo() {},
      },
      setSegment: null,
      stackingAdapter: {
        notifyParentPositionMachineNext() {
          calls.push("parent position");
        },
        updateTravelProgress() {
          calls.push("stack progress");
        },
      },
      state: {
        openness: {
          isClosing: false,
          isOpen: false,
          isOpening: true,
          completeAnimation() {
            calls.push("openness");
            this.isOpening = false;
            this.isOpen = true;
          },
        },
        position: {
          isFrontClosing: false,
          isFrontOpening: true,
          advance() {
            calls.push("position");
            this.isFrontOpening = false;
          },
        },
        staging: {
          current: "opening",
          advance() {
            calls.push("staging");
            this.current = "none";
          },
          matches() {
            return false;
          },
        },
      },
      steppingAnimationSettings: null,
      swipeOutDisabledWithDetent: false,
      tracks: "bottom",
      travelAnimations: [],
      view: document.createElement("div"),
    };
    controller.setSegment = (segment) => {
      controller.currentSegment = segment;
    };
    controller.onTravelEnd = () => {
      calls.push([
        "public end",
        controller.state.openness.isOpen,
        controller.state.position.isFrontOpening,
        controller.state.staging.current,
      ]);
    };

    new AnimationTravel(controller).animateToDetent(1, { skip: true });

    assert.deepEqual(calls, [
      "openness",
      "position",
      "parent position",
      "staging",
      ["public end", true, false, "none"],
      "stack progress",
    ]);
  });

  test("cleanup stops an active smooth travel frame loop and callbacks", async function (assert) {
    const animationFrames = stubAnimationFrameQueue();
    const calls = [];
    const controller = new Controller();

    controller.activeDetent = 1;
    controller.currentSegment = [1, 1];
    controller.view = document.createElement("div");
    controller.contentWrapper = document.createElement("div");
    controller.scrollContainer = {
      scrollLeft: 0,
      scrollTop: 0,
      scrollTo() {},
    };
    controller.dimensions = dimensions();
    controller.onTravelStart = () => calls.push("start");
    controller.onTravel = () => calls.push("travel");
    controller.onTravelEnd = () => calls.push("end");

    controller.animationTravel.animateToDetent(0, {
      contentMove: false,
      duration: 4,
      easing: "linear",
    });

    assert.deepEqual(calls, ["start"], "travel starts synchronously");

    animationFrames.flush();
    animationFrames.flush();

    assert.strictEqual(
      animationFrames.size,
      1,
      "the active progress loop has one pending frame"
    );

    controller.cleanup();
    animationFrames.flush(1);
    await Promise.resolve();
    await Promise.resolve();

    assert.deepEqual(
      calls,
      ["start"],
      "cleanup suppresses post-destroy travel and end callbacks"
    );
    assert.strictEqual(
      animationFrames.size,
      0,
      "the cancelled progress loop does not schedule another frame"
    );
  });
});

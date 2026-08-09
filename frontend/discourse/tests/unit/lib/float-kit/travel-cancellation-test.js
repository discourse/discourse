import { module, test } from "qunit";
import sinon from "sinon";
import AnimationTravel from "discourse/float-kit/components/d-sheet/animation-travel";
import { travelToDetent } from "discourse/float-kit/components/d-sheet/travel";

class FakeAnimation {
  cancelCount = 0;
  #listeners = new Map();

  addEventListener(type, callback) {
    this.#listeners.set(type, callback);
  }

  removeEventListener(type, callback) {
    if (this.#listeners.get(type) === callback) {
      this.#listeners.delete(type);
    }
  }

  cancel() {
    this.cancelCount++;
    this.#listeners.get("cancel")?.();
  }

  finish() {
    this.#listeners.get("finish")?.();
  }
}

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
    progressValueAtDetents: [
      { after: 0, before: 0, exact: 0 },
      { after: 1, before: 1, exact: 1 },
    ],
    snapOutAccelerator: { travelAxis: { unitless: 10 } },
    view: { travelAxis: { unitless: 100 } },
  };
}

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
      const pending = [...callbacks];
      for (const [id, callback] of pending) {
        callbacks.delete(id);
        callback(timestamp);
      }
    },
  };
}

function startTravel({ onTravelEnd = null } = {}) {
  const animations = [];
  const contentWrapper = document.createElement("div");
  const outlet = document.createElement("div");
  const view = document.createElement("div");

  contentWrapper.getBoundingClientRect = () => ({ left: 0, top: 60 });
  view.getBoundingClientRect = () => ({ left: 0, top: 0 });

  for (const target of [contentWrapper, outlet]) {
    target.animate = () => {
      const animation = new FakeAnimation();
      animations.push(animation);
      return animation;
    };
  }

  const cancel = travelToDetent({
    animationConfig: { duration: 10, easing: "linear" },
    belowSheetsInStack: [],
    contentPlacement: "bottom",
    contentWrapper,
    currentDetent: 0,
    destinationDetent: 1,
    dimensions: dimensions(),
    hasOppositeTracks: false,
    onTravelEnd,
    scrollContainer: {
      scrollTo() {},
    },
    setSegment() {},
    swipeOutDisabledWithDetent: false,
    tracks: "bottom",
    travelAnimations: [
      {
        config: { opacity: [0, 1] },
        target: outlet,
      },
    ],
    view,
  });

  return { animations, cancel, outlet };
}

module("Unit | Lib | float-kit | travel-cancellation", function (hooks) {
  hooks.afterEach(() => sinon.restore());

  test("cancellation owns queued frames and Web Animations", async function (assert) {
    const frames = stubAnimationFrames();
    const onTravelEnd = sinon.spy();
    const { animations, cancel, outlet } = startTravel({ onTravelEnd });

    frames.flush();
    frames.flush(1);

    assert.strictEqual(animations.length, 2, "both animation channels start");
    assert.strictEqual(frames.size, 1, "the progress loop owns one frame");

    cancel();
    for (const animation of animations) {
      animation.finish();
    }
    await Promise.resolve();

    assert.deepEqual(
      animations.map((animation) => animation.cancelCount),
      [1, 1],
      "content and outlet animations are cancelled"
    );
    assert.strictEqual(frames.size, 0, "the progress frame is cancelled");
    assert.strictEqual(
      outlet.style.opacity,
      "",
      "a cancelled outlet cannot persist its final keyframe"
    );
    assert.false(onTravelEnd.called, "cancelled travel does not report an end");
  });

  test("AnimationTravel cancels its owned travel", function (assert) {
    const frames = stubAnimationFrames();
    const animations = [new FakeAnimation(), new FakeAnimation()];
    const outlet = document.createElement("div");
    const controller = {
      activeDetent: 0,
      belowSheetsInStack: [],
      contentPlacement: "bottom",
      contentWrapper: null,
      dimensions: dimensions(),
      edgeAlignedNoOvershoot: false,
      enteringAnimationSettings: null,
      exitingAnimationSettings: null,
      scrollContainer: { scrollTo() {} },
      setSegment() {},
      state: {},
      steppingAnimationSettings: null,
      tracks: "bottom",
      travelAnimations: [],
      view: null,
    };
    const contentWrapper = document.createElement("div");
    const view = document.createElement("div");

    contentWrapper.getBoundingClientRect = () => ({ left: 0, top: 60 });
    view.getBoundingClientRect = () => ({ left: 0, top: 0 });
    contentWrapper.animate = () => animations[0];
    outlet.animate = () => animations[1];
    controller.contentWrapper = contentWrapper;
    controller.view = view;
    controller.travelAnimations.push({
      config: { opacity: [0, 1] },
      target: outlet,
    });

    const animationTravel = new AnimationTravel(controller);
    animationTravel.animateToDetent(1, {
      duration: 10,
      easing: "linear",
    });
    frames.flush();
    frames.flush(1);
    animationTravel.cancelActiveTravel();

    assert.deepEqual(
      animations.map((animation) => animation.cancelCount),
      [1, 1],
      "the travel owner cancels both Web Animations"
    );
    assert.strictEqual(frames.size, 0, "the owner cancels the progress frame");
  });
});

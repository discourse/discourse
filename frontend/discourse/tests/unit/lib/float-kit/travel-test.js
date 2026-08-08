import { module, test } from "qunit";
import sinon from "sinon";
import {
  createTravelEasing,
  travelToDetent,
} from "discourse/float-kit/components/d-sheet/travel";

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
    view: { travelAxis: { unitless: 100 } },
  };
}

function scrollContainer() {
  return {
    scrollLeft: null,
    scrollTop: null,
    scrollTo(left, top) {
      this.scrollLeft = left;
      this.scrollTop = top;
    },
  };
}

function instantTravelOptions(overrides = {}) {
  return {
    animationConfig: { skip: true },
    belowSheetsInStack: [],
    contentPlacement: "bottom",
    currentDetent: 0,
    destinationDetent: 1,
    dimensions: dimensions(),
    hasOppositeTracks: false,
    scrollContainer: scrollContainer(),
    setSegment() {},
    swipeOutDisabledWithDetent: false,
    tracks: "bottom",
    travelAnimations: [],
    ...overrides,
  };
}

module("Unit | Lib | float-kit | travel", function (hooks) {
  hooks.afterEach(() => sinon.restore());

  test("falls back from an invalid single-stop linear easing", function (assert) {
    assert.strictEqual(
      createTravelEasing([0.00052], true),
      "linear",
      "short spring travels use a valid Web Animations easing"
    );
    assert.strictEqual(
      createTravelEasing([0, 0.5, 1], true),
      "linear(0,0.5,1)",
      "multi-stop spring travels retain their optimized easing"
    );
  });

  test("short spring travel passes valid easing to Web Animations", async function (assert) {
    let timestamp = 0;
    const animationOptions = [];
    const animation = {
      addEventListener(type, callback) {
        if (type === "finish") {
          queueMicrotask(callback);
        }
      },
      removeEventListener() {},
    };
    const contentWrapper = {
      animate(_keyframes, options) {
        animationOptions.push(options);
        return animation;
      },
      getBoundingClientRect() {
        return { left: 0, top: 60.5 };
      },
    };

    sinon.stub(CSS, "supports").returns(true);
    sinon.stub(window, "requestAnimationFrame").callsFake((callback) => {
      callback(timestamp++);
      return timestamp;
    });

    travelToDetent({
      ...instantTravelOptions({
        animationConfig: {
          damping: 44,
          easing: "spring",
          mass: 1,
          stiffness: 520,
        },
        contentWrapper,
        currentDetent: 1,
        destinationDetent: 0,
        view: {
          getBoundingClientRect() {
            return { left: 0, top: 0 };
          },
        },
      }),
    });

    await Promise.resolve();

    assert.deepEqual(
      animationOptions.map(({ easing }) => easing),
      ["linear"],
      "Element.animate never receives a one-stop linear() easing"
    );
  });

  test("instant travel runs final callbacks before ending", function (assert) {
    const calls = [];
    const options = instantTravelOptions({
      belowSheetsInStack: [
        {
          selfAndAboveTravelProgressSum: [0.25],
          aggregatedStackingCallback(progress, tween) {
            calls.push(["stacking", progress, typeof tween]);
          },
        },
      ],
      onTravel(payload) {
        calls.push(["onTravel", payload]);
      },
      onTravelEnd() {
        calls.push(["end"]);
      },
      onTravelStart() {
        calls.push(["start"]);
      },
      setSegment(segment) {
        calls.push(["segment", segment]);
      },
      travelAnimations: [
        {
          callback(progress, tween) {
            calls.push(["travel", progress, typeof tween]);
          },
        },
      ],
    });

    travelToDetent(options);

    assert.deepEqual(calls, [
      ["start"],
      ["segment", [1, 1]],
      [
        "onTravel",
        {
          progress: 1,
          progressAtDetents: [0, 1],
          range: { start: 1, end: 1 },
        },
      ],
      ["travel", 1, "function"],
      ["stacking", 1.25, "function"],
      ["end"],
    ]);
  });

  test("reveals an opening view only when travel is positioned", function (assert) {
    const frames = [];
    const view = {
      dataset: { dSheet: "view bottom hidden staging-opening" },
      getBoundingClientRect() {
        return { left: 0, top: 0 };
      },
    };

    sinon.stub(window, "requestAnimationFrame").callsFake((callback) => {
      frames.push(callback);
      return frames.length;
    });

    travelToDetent(
      instantTravelOptions({
        animationConfig: {
          damping: 44,
          easing: "spring",
          mass: 1,
          stiffness: 520,
        },
        contentWrapper: {
          animate() {
            return {
              addEventListener() {},
              removeEventListener() {},
            };
          },
          getBoundingClientRect() {
            return { left: 0, top: 60 };
          },
        },
        view,
      })
    );

    assert.true(
      view.dataset.dSheet.split(" ").includes("hidden"),
      "the view stays hidden before travel initialization"
    );

    frames.shift()(0);

    assert.true(
      view.dataset.dSheet.split(" ").includes("hidden"),
      "the view stays hidden through the first animation frame"
    );

    frames.shift()(1);

    assert.strictEqual(
      view.dataset.dSheet,
      "view bottom staging-opening",
      "the view is revealed after its final scroll position is applied"
    );
  });

  test("instant travel reveals an opening view", function (assert) {
    const view = { dataset: { dSheet: "view hidden bottom" } };

    travelToDetent(instantTravelOptions({ view }));

    assert.strictEqual(
      view.dataset.dSheet,
      "view bottom",
      "skip and reduced-motion travel cannot leave the view hidden"
    );
  });

  test("centered tracks default to the bottom and right edges", function (assert) {
    for (const tracks of ["vertical", "horizontal"]) {
      const container = scrollContainer();

      travelToDetent(
        instantTravelOptions({
          contentPlacement: "center",
          destinationDetent: 0,
          hasOppositeTracks: true,
          runTravelCallbacksAndAnimations: false,
          scrollContainer: container,
          tracks,
        })
      );

      assert.deepEqual(
        [container.scrollLeft, container.scrollTop],
        [0, 0],
        `${tracks} closes toward its Silk default edge`
      );
    }
  });
});

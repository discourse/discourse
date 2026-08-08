import { module, test } from "qunit";
import ScrollProgressCalculator from "discourse/float-kit/components/d-sheet/scroll-progress-calculator";

function centeredController(tracks) {
  return {
    contentPlacement: "center",
    dimensions: {
      content: { travelAxis: { unitless: 60 } },
      scroll: { travelAxis: { unitless: 100 } },
      snapOutAccelerator: { travelAxis: { unitless: 10 } },
    },
    edgeAlignedNoOvershoot: false,
    scrollContainer: {
      scrollLeft: 0,
      scrollTop: 0,
    },
    snapToEndDetentsAcceleration: "auto",
    swipeOutDisabledWithDetent: false,
    tracks,
  };
}

module("Unit | Lib | float-kit | scroll-progress-calculator", function () {
  test("centered tracks measure progress symmetrically", function (assert) {
    for (const tracks of ["vertical", "horizontal"]) {
      const controller = centeredController(tracks);
      const calculator = new ScrollProgressCalculator(controller);
      const scrollProperty = tracks === "vertical" ? "scrollTop" : "scrollLeft";

      controller.scrollContainer[scrollProperty] = 90;
      assert.strictEqual(
        calculator.calculateProgress().rawProgress,
        1,
        `${tracks} progress is complete at the resting position`
      );

      controller.scrollContainer[scrollProperty] = 50;
      const progressTowardStart = calculator.calculateProgress().rawProgress;

      controller.scrollContainer[scrollProperty] = 130;
      const progressTowardEnd = calculator.calculateProgress().rawProgress;

      assert.strictEqual(
        progressTowardStart,
        0.5,
        `${tracks} progress decreases toward the start edge`
      );
      assert.strictEqual(
        progressTowardEnd,
        progressTowardStart,
        `${tracks} progress decreases equally toward the end edge`
      );
    }
  });

  test("progress beyond the final detent has no range", function (assert) {
    const controller = centeredController("vertical");
    controller.dimensions.progressValueAtDetents = [
      { before: -0.02, exact: 0, after: 0.02 },
      { before: 0.98, exact: 1, after: 1.02 },
    ];

    const calculator = new ScrollProgressCalculator(controller);

    assert.strictEqual(calculator.determineSegment(1.2), null);
  });
});

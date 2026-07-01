import { module, test } from "qunit";
import DimensionCalculator from "discourse/float-kit/components/d-sheet/dimensions-calculator";

module("Unit | Lib | float-kit | dimensions-calculator", function () {
  test("preserves the WebKit small spacer mode on calculated dimensions", function (assert) {
    const originalGetComputedStyle = window.getComputedStyle;
    const view = document.createElement("div");
    const content = document.createElement("div");

    window.getComputedStyle = (element) => ({
      getPropertyValue(property) {
        if (property === "height") {
          return element === view ? "100px" : "60px";
        }

        if (property === "width") {
          return "40px";
        }

        return "";
      },
    });

    try {
      const calculator = new DimensionCalculator({
        view,
        content,
        detentMarkers: [],
      });

      const dimensions = calculator.calculateDimensions("bottom", "bottom", {
        webkitSmallSpacerMode: true,
      });

      assert.true(
        dimensions.webkitSmallSpacerMode,
        "the progress calculator can read the WebKit spacer mode"
      );
    } finally {
      window.getComputedStyle = originalGetComputedStyle;
    }
  });
});

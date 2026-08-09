import { module, test } from "qunit";
import DimensionCalculator from "discourse/float-kit/components/d-sheet/dimensions-calculator";

module("Unit | Lib | float-kit | dimensions-calculator", function () {
  test("measures all elements before publishing CSS dimensions", function (assert) {
    const originalGetComputedStyle = window.getComputedStyle;
    const view = document.createElement("div");
    const content = document.createElement("div");
    const marker = document.createElement("div");
    const operations = [];
    const originalSetProperty = view.style.setProperty.bind(view.style);

    window.getComputedStyle = (element) => {
      operations.push(`read:${element.dataset.element}`);

      return {
        getPropertyValue(property) {
          if (property === "height") {
            if (element === view) {
              return "100px";
            }
            return element === content ? "60px" : "30px";
          }

          return "40px";
        },
      };
    };
    view.style.setProperty = (property, value) => {
      operations.push(`write:${property}`);
      originalSetProperty(property, value);
    };
    view.dataset.element = "view";
    content.dataset.element = "content";
    marker.dataset.element = "marker";

    try {
      const calculator = new DimensionCalculator({
        view,
        content,
        detentMarkers: [marker],
      });

      calculator.calculateDimensions("bottom", "bottom");

      const firstWrite = operations.findIndex((operation) =>
        operation.startsWith("write:")
      );
      const lastRead = operations.findLastIndex((operation) =>
        operation.startsWith("read:")
      );
      const writes = operations.filter((operation) =>
        operation.startsWith("write:")
      );

      assert.true(
        lastRead < firstWrite,
        "the calculator completes every layout read before its first write"
      );
      assert.strictEqual(
        new Set(writes).size,
        writes.length,
        "each CSS dimension is published once"
      );
    } finally {
      window.getComputedStyle = originalGetComputedStyle;
    }
  });

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

  test("centered tracks preserve the dismissal-disabled detent spacer", function (assert) {
    const originalGetComputedStyle = window.getComputedStyle;
    const view = document.createElement("div");
    const content = document.createElement("div");
    const firstMarker = document.createElement("div");
    const lastMarker = document.createElement("div");

    window.getComputedStyle = (element) => ({
      getPropertyValue(property) {
        if (property === "height") {
          if (element === view) {
            return "100px";
          }
          if (element === content) {
            return "60px";
          }
          return "20px";
        }

        return "40px";
      },
    });

    try {
      const calculator = new DimensionCalculator({
        view,
        content,
        detentMarkers: [firstMarker, lastMarker],
      });

      const dimensions = calculator.calculateDimensions("vertical", "center", {
        edgeAlignedNoOvershoot: true,
        snapOutAcceleration: "initial",
        snapToEndDetentsAcceleration: "auto",
        swipeOutDisabledWithDetent: true,
      });

      assert.strictEqual(
        dimensions.frontSpacer.travelAxis.unitless,
        50,
        "the spacer is content minus the first detent plus snap-back padding"
      );

      const explicitAccelerationDimensions = calculator.calculateDimensions(
        "vertical",
        "center",
        {
          edgeAlignedNoOvershoot: true,
          snapOutAcceleration: "initial",
          snapToEndDetentsAcceleration: null,
          swipeOutDisabledWithDetent: true,
        }
      );

      assert.strictEqual(
        explicitAccelerationDimensions.frontSpacer.travelAxis.unitless,
        41,
        "explicit acceleration retains the one-pixel front snap offset"
      );
      assert.strictEqual(
        explicitAccelerationDimensions.backSpacer.travelAxis.unitless,
        101,
        "explicit acceleration retains the one-pixel back snap offset"
      );
    } finally {
      window.getComputedStyle = originalGetComputedStyle;
    }
  });
});

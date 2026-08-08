import { module, test } from "qunit";
import {
  createOutletAnimationKeyframe,
  normalizeOutletAnimationConfig,
} from "discourse/float-kit/components/d-sheet/outlet-animation-config";

module("Unit | Lib | float-kit | outlet animation config", function () {
  test("normalizes nested properties for smooth keyframes", function (assert) {
    const { staticStyles, templates } = normalizeOutletAnimationConfig({
      properties: {
        color: "red",
        opacity: [0, 1],
      },
    });

    assert.deepEqual(createOutletAnimationKeyframe(templates, 0.5), {
      opacity: "calc(0 + (1 - 0) * 0.5)",
    });
    assert.strictEqual(staticStyles.get("color"), "red");
  });

  test("combines explicit and property transforms", function (assert) {
    const { templates } = normalizeOutletAnimationConfig({
      transform: ({ progress }) => `rotate(${progress}deg)`,
      scale: [0.8, 1],
    });

    assert.deepEqual(createOutletAnimationKeyframe(templates, 0.5), {
      transform: "rotate(0.5deg) scale(calc(0.8 + (1 - 0.8) * 0.5))",
    });
  });
});

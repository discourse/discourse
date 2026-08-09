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

  test("precomputes style property names without changing keyframe templates", function (assert) {
    const animationFunction = ({ progress }) => String(progress);
    const { styleTemplates, templates } = normalizeOutletAnimationConfig({
      backgroundColor: animationFunction,
    });

    assert.strictEqual(
      templates[0][0],
      "backgroundColor",
      "keyframes retain the JavaScript property name"
    );
    assert.strictEqual(
      styleTemplates[0][0],
      "background-color",
      "inline styles receive a precomputed CSS property name"
    );
    assert.strictEqual(
      styleTemplates[0][1],
      templates[0][1],
      "both paths share the configured animation function"
    );
  });

  test("collects transform and opacity will-change properties", function (assert) {
    const { staticStyles, willChangeProperties } =
      normalizeOutletAnimationConfig({
        opacity: "ignore",
        translateY: ({ progress }) => `${progress}px`,
        transformOrigin: "50% 0",
      });

    assert.deepEqual(
      [...willChangeProperties],
      ["opacity", "transform"],
      "the composited animation properties retain configuration order"
    );
    assert.false(
      staticStyles.has("opacity"),
      "an ignored animation remains excluded from declarative styles"
    );
  });

  test("excludes config willChange from animation styles", function (assert) {
    const {
      animatedProperties,
      staticStyles,
      styleTemplates,
      templates,
      willChangeProperties,
    } = normalizeOutletAnimationConfig({ willChange: "contents" });

    assert.strictEqual(staticStyles.size, 0, "it is not a static style");
    assert.deepEqual(templates, [], "it is not a keyframe template");
    assert.deepEqual(styleTemplates, [], "it is not an inline template");
    assert.strictEqual(
      animatedProperties.size,
      0,
      "it is not an animated property"
    );
    assert.strictEqual(
      willChangeProperties.size,
      0,
      "it is not a generated compositing hint"
    );
  });
});

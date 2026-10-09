import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  measuredMax,
  measuredMin,
  measuredSize,
} from "discourse/lib/resize-measurements";

/**
 * Appends a styled box and removes it when the test ends.
 *
 * @param {object} hooks - The QUnit hooks the cleanup registers against.
 * @returns {(css: string) => HTMLElement} A factory taking inline styles.
 */
function boxFactory(hooks) {
  const created = [];
  hooks.afterEach(function () {
    created.splice(0).forEach((element) => element.remove());
  });

  return (css) => {
    const element = document.createElement("div");
    element.style.cssText = `position:absolute;top:-9999px;${css}`;
    document.body.appendChild(element);
    created.push(element);
    return element;
  };
}

module("Unit | Lib | resize-measurements", function (hooks) {
  setupTest(hooks);
  const box = boxFactory(hooks);

  module("measuredSize round-trips what consumers write", function () {
    const CASES = [
      { boxSizing: "content-box", padding: "0" },
      { boxSizing: "content-box", padding: "10px" },
      { boxSizing: "border-box", padding: "0" },
      { boxSizing: "border-box", padding: "10px" },
    ];

    for (const { boxSizing, padding } of CASES) {
      for (const axis of ["vertical", "horizontal"]) {
        const property = axis === "vertical" ? "height" : "width";

        test(`${axis}, ${boxSizing}, padding ${padding}`, function (assert) {
          const element = box(
            `box-sizing:${boxSizing};border:1px solid;padding:${padding};` +
              `height:400px;width:400px;`
          );

          element.style[property] = "440px";

          assert.strictEqual(
            measuredSize(element, axis),
            440,
            "reads back the number that was written"
          );
        });
      }
    }

    test("a written fraction is preserved rather than rounded", function (assert) {
      const element = box("box-sizing:border-box;height:100px;width:100px;");
      element.style.height = "440.5px";

      assert.strictEqual(measuredSize(element, "vertical"), 440.5);
    });

    test("a flex item reports the height it was given", function (assert) {
      const parent = box("display:flex;flex-direction:column;height:600px;");
      const child = document.createElement("div");
      child.style.cssText = "box-sizing:content-box;border:1px solid;";
      parent.appendChild(child);

      child.style.height = "440px";

      assert.strictEqual(measuredSize(child, "vertical"), 440);
    });
  });

  module("measuredSize refuses a box that is not laid out", function () {
    test("a detached element is unmeasured", function (assert) {
      const element = document.createElement("div");
      element.style.height = "440px";

      assert.strictEqual(measuredSize(element, "vertical"), null);
    });

    test("a display:none element is unmeasured, percentage height and all", function (assert) {
      // With no box, CSSOM returns the computed value, so a percentage
      // survives as a plausible-looking number.
      const parent = box("height:800px;");
      const child = document.createElement("div");
      child.style.cssText = "display:none;height:50%;";
      parent.appendChild(child);

      assert.strictEqual(measuredSize(child, "vertical"), null);
    });

    test("an auto height is unmeasured", function (assert) {
      const parent = box("display:none;");
      const child = document.createElement("div");
      child.style.cssText = "height:auto;";
      parent.appendChild(child);

      assert.strictEqual(measuredSize(child, "vertical"), null);
    });
  });

  module("measuredMax never lands below measuredMin", function () {
    test("a declared minimum above the cap wins", function (assert) {
      const element = box("min-height:400px;height:400px;");

      assert.strictEqual(measuredMin(element, "vertical"), 400);
      assert.strictEqual(
        measuredMax(element, "vertical", 300),
        400,
        "the floor beats a cap that would announce an impossible range"
      );
    });

    test("a declared maximum below the minimum still loses to it", function (assert) {
      const element = box("min-height:400px;max-height:300px;height:400px;");

      assert.strictEqual(measuredMax(element, "vertical", 1000), 400);
    });

    test("the cap still wins when it sits above the minimum", function (assert) {
      const element = box("min-height:200px;height:200px;");

      assert.strictEqual(measuredMax(element, "vertical", 500), 500);
    });

    test("a detached element is capped, with no minimum to floor against", function (assert) {
      const element = document.createElement("div");

      assert.strictEqual(measuredMax(element, "vertical", 300), 300);
    });
  });
});

import { module, test } from "qunit";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";

const POLL_VARS = [1, 2, 3, 4, 5].map((i) => `--poll-pie-color-${i}`);

module("Unit | Utility | chart-colors", function (hooks) {
  hooks.afterEach(function () {
    POLL_VARS.forEach((name) =>
      document.documentElement.style.removeProperty(name)
    );
  });

  function setPollColors(...colors) {
    colors.forEach((color, i) =>
      document.documentElement.style.setProperty(POLL_VARS[i], color)
    );
  }

  test("returns gradient colors when no CSS variables defined", function (assert) {
    const colors = getColors(3);

    assert.strictEqual(colors.length, 3, "returns 3 colors");
    assert.true(
      colors.every((c) => c.startsWith("rgb(")),
      "all colors are rgb format"
    );
  });

  test("returns CSS colors when all are defined", function (assert) {
    setPollColors("red", "blue", "green");

    const colors = getColors(3);

    assert.deepEqual(
      colors,
      ["rgb(255, 0, 0)", "rgb(0, 0, 255)", "rgb(0, 128, 0)"],
      "returns the resolved CSS colors in order"
    );
  });

  test("mixes CSS and gradient colors when partially defined", function (assert) {
    setPollColors("hotpink", "cyan");

    const colors = getColors(5);

    assert.strictEqual(colors.length, 5, "returns 5 colors");
    assert.strictEqual(
      colors[0],
      "rgb(255, 105, 180)",
      "first color is from CSS"
    );
    assert.strictEqual(
      colors[1],
      "rgb(0, 255, 255)",
      "second color is from CSS"
    );
    assert.true(colors[2].startsWith("rgb("), "third color is from gradient");
    assert.true(colors[3].startsWith("rgb("), "fourth color is from gradient");
    assert.true(colors[4].startsWith("rgb("), "fifth color is from gradient");
  });
});

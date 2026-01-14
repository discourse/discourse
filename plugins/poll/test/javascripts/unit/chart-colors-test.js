import { module, test } from "qunit";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";

module("Unit | Utility | chart-colors", function (hooks) {
  hooks.beforeEach(function () {
    this.originalGetComputedStyle = window.getComputedStyle;
  });

  hooks.afterEach(function () {
    window.getComputedStyle = this.originalGetComputedStyle;
  });

  test("returns gradient colors when no CSS variables defined", function (assert) {
    window.getComputedStyle = () => ({
      getPropertyValue: () => "",
    });

    const colors = getColors(3);

    assert.strictEqual(colors.length, 3, "returns 3 colors");
    assert.true(
      colors.every((c) => c.startsWith("rgb(")),
      "all colors are rgb format"
    );
  });

  test("returns CSS colors when all are defined", function (assert) {
    const cssColors = {
      "--poll-pie-color-1": "red",
      "--poll-pie-color-2": "blue",
      "--poll-pie-color-3": "green",
    };

    window.getComputedStyle = () => ({
      getPropertyValue: (varName) => cssColors[varName] || "",
    });

    const colors = getColors(3);

    assert.strictEqual(colors.length, 3, "returns 3 colors");
    assert.strictEqual(colors[0], "red", "first color is red");
    assert.strictEqual(colors[1], "blue", "second color is blue");
    assert.strictEqual(colors[2], "green", "third color is green");
  });

  test("mixes CSS and gradient colors when partially defined", function (assert) {
    const cssColors = {
      "--poll-pie-color-1": "hotpink",
      "--poll-pie-color-2": "cyan",
    };

    window.getComputedStyle = () => ({
      getPropertyValue: (varName) => cssColors[varName] || "",
    });

    const colors = getColors(5);

    assert.strictEqual(colors.length, 5, "returns 5 colors");
    assert.strictEqual(colors[0], "hotpink", "first color is from CSS");
    assert.strictEqual(colors[1], "cyan", "second color is from CSS");
    assert.true(colors[2].startsWith("rgb("), "third color is from gradient");
    assert.true(colors[3].startsWith("rgb("), "fourth color is from gradient");
    assert.true(colors[4].startsWith("rgb("), "fifth color is from gradient");
  });
});

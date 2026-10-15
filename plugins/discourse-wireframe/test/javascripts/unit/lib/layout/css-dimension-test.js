import { module, test } from "qunit";
import {
  formatDimension,
  parseDimension,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/css-dimension";

module("Unit | Discourse Wireframe | css-dimension", function () {
  test("parseDimension splits a CSS string into value and unit", function (assert) {
    assert.deepEqual(parseDimension("16px"), { value: 16, unit: "px" });
    assert.deepEqual(parseDimension("1.5rem"), { value: 1.5, unit: "rem" });
    assert.deepEqual(parseDimension("50%"), { value: 50, unit: "%" });
    assert.deepEqual(parseDimension("-2em"), { value: -2, unit: "em" });
  });

  test("parseDimension tolerates surrounding whitespace", function (assert) {
    assert.deepEqual(parseDimension("  12 px "), { value: 12, unit: "px" });
  });

  test("parseDimension returns a bare number with an empty unit", function (assert) {
    assert.deepEqual(parseDimension(1), { value: 1, unit: "" });
    assert.deepEqual(parseDimension("3"), { value: 3, unit: "" });
  });

  test("parseDimension returns null for nullish / unparseable values", function (assert) {
    assert.strictEqual(parseDimension(null), null);
    assert.strictEqual(parseDimension(undefined), null);
    assert.strictEqual(parseDimension(""), null);
    assert.strictEqual(parseDimension("auto"), null);
    assert.strictEqual(parseDimension("minmax(80px, auto)"), null);
    assert.strictEqual(parseDimension(NaN), null);
  });

  test("formatDimension returns a bare Number when the unit is empty", function (assert) {
    const result = formatDimension(2, "");
    assert.strictEqual(result, 2);
    assert.strictEqual(typeof result, "number", "stays a Number, not a string");
  });

  test("formatDimension joins value and unit into a CSS string", function (assert) {
    assert.strictEqual(formatDimension(16, "px"), "16px");
    assert.strictEqual(formatDimension(1.5, "rem"), "1.5rem");
  });

  test("formatDimension returns null for nullish / non-finite values", function (assert) {
    assert.strictEqual(formatDimension(null, "px"), null);
    assert.strictEqual(formatDimension(undefined, "px"), null);
    assert.strictEqual(formatDimension(NaN, "px"), null);
  });

  test("round-trips a unitless value as a Number", function (assert) {
    const parsed = parseDimension(1);
    assert.strictEqual(formatDimension(parsed.value, parsed.unit), 1);
  });

  test("round-trips a unit value as a string", function (assert) {
    const parsed = parseDimension("16rem");
    assert.strictEqual(formatDimension(parsed.value, parsed.unit), "16rem");
  });
});

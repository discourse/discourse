import { module, test } from "qunit";
import {
  formatChartDateLabel,
  looksLikeDate,
} from "../../discourse/lib/chart-helpers";

module("Unit | Lib | chart-helpers", function () {
  test("detects compact date labels for chart defaults", function (assert) {
    assert.true(looksLikeDate("Jan 03"), "detects month/day labels");
    assert.true(looksLikeDate("Jan 24"), "detects month/year labels");
    assert.true(looksLikeDate("Jan 2024"), "detects long month/year labels");
  });

  test("formats tooltip labels without inventing years for compact labels", function (assert) {
    assert.strictEqual(
      formatChartDateLabel("2024-01-03"),
      "January 3, 2024",
      "expands ISO dates"
    );
    assert.strictEqual(
      formatChartDateLabel("Jan 03"),
      "Jan 3",
      "normalizes month/day labels"
    );
    assert.strictEqual(
      formatChartDateLabel("Jan 24"),
      "Jan 24",
      "leaves ambiguous compact labels alone"
    );
    assert.strictEqual(
      formatChartDateLabel("Jan 2024"),
      "Jan 2024",
      "leaves month/year labels alone"
    );
  });
});

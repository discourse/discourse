import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  formatDeltaPercent,
  formatKpiValue,
} from "discourse/admin/lib/dashboard-format";

module("Unit | Admin | Lib | dashboard-format", function (hooks) {
  setupTest(hooks);

  module("formatKpiValue", function () {
    test("returns an em dash when the value is null", function (assert) {
      assert.strictEqual(formatKpiValue("new_signups", null), "—");
    });

    test("formats a count with no decimals and a thousands separator", function (assert) {
      assert.strictEqual(formatKpiValue("new_signups", 1100), "1,100");
    });

    test("formats a percentage KPI with a percent suffix and one decimal", function (assert) {
      assert.strictEqual(formatKpiValue("dau_mau", 21.6), "21.6%");
    });
  });

  module("formatDeltaPercent", function () {
    test("prefixes a positive delta with a plus and rounds to a whole percent", function (assert) {
      assert.strictEqual(formatDeltaPercent(12.02), "+12%");
    });

    test("keeps one decimal for a sub-1% positive delta", function (assert) {
      assert.strictEqual(formatDeltaPercent(0.4), "+0.4%");
    });

    test("keeps one decimal and a minus sign for a sub-1% negative delta", function (assert) {
      assert.strictEqual(formatDeltaPercent(-0.4), "-0.4%");
    });

    test("renders an exact-zero delta without a sign", function (assert) {
      assert.strictEqual(formatDeltaPercent(0), "0%");
    });

    test("rounds a larger negative delta and keeps the minus sign", function (assert) {
      assert.strictEqual(formatDeltaPercent(-38.5), "-38%");
    });
  });
});

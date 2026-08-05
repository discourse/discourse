import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  ALL_PRESETS,
  calculatePresetStartDate,
  PERIOD_CUSTOM,
} from "discourse/admin/lib/dashboard-date-range";

module("Unit | Controller | admin-dashboard-traffic", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.clock = sinon.useFakeTimers({
      now: new Date("2026-08-05T12:00:00Z"),
      shouldAdvanceTime: false,
    });
    this.controller = this.owner.lookup("controller:admin-dashboard-traffic");
  });

  hooks.afterEach(function () {
    this.clock.restore();
  });

  test("period identifies each preset date range", function (assert) {
    for (const period of ALL_PRESETS) {
      this.controller.start_date = moment(
        calculatePresetStartDate(period)
      ).format("YYYY-MM-DD");
      this.controller.end_date = moment().format("YYYY-MM-DD");

      assert.strictEqual(
        this.controller.period,
        period,
        `identifies ${period}`
      );
    }
  });

  test("period identifies a custom date range", function (assert) {
    this.controller.start_date = "2026-07-01";
    this.controller.end_date = "2026-07-14";

    assert.strictEqual(this.controller.period, PERIOD_CUSTOM);
  });
});

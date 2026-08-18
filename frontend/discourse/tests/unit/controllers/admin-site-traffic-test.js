import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Controller | admin-site-traffic", function (hooks) {
  setupTest(hooks);

  test("a precise range updates its parent dates and can be cleared", function (assert) {
    const controller = this.owner.lookup("controller:admin-site-traffic");
    controller.range = "custom";
    controller.start_date = "2026-05-01";
    controller.end_date = "2026-05-12";

    controller.setPreciseRange(
      new Date("2026-05-10T10:03:00Z"),
      new Date("2026-05-10T10:06:00Z")
    );

    assert.deepEqual(
      [
        controller.range,
        controller.start_date,
        controller.end_date,
        controller.startDate.toISOString(),
        controller.endDate.toISOString(),
      ],
      [
        "custom",
        "2026-05-10",
        "2026-05-10",
        "2026-05-10T10:03:00.000Z",
        "2026-05-10T10:06:00.000Z",
      ],
      "the brush scopes both the exact range and its parent dates"
    );

    controller.clearPreciseRange();

    assert.deepEqual(
      [
        controller.hasPreciseRange,
        moment(controller.startDate).format("YYYY-MM-DD HH:mm:ss"),
        moment(controller.endDate).format("YYYY-MM-DD HH:mm:ss"),
      ],
      [false, "2026-05-10 00:00:00", "2026-05-10 23:59:59"],
      "zooming out restores the parent date range"
    );
  });

  test("whole-day picker values clear precision without clearing grouping", function (assert) {
    const controller = this.owner.lookup("controller:admin-site-traffic");
    controller.grouping = "hour";
    controller.setPreciseRange(
      new Date("2026-05-10T10:00:00Z"),
      new Date("2026-05-10T12:00:00Z")
    );

    controller.setCustomDateRange(
      new Date("2026-05-10T00:00:00Z"),
      new Date("2026-05-10T23:59:00Z")
    );

    assert.deepEqual(
      [
        controller.range,
        controller.start_date,
        controller.end_date,
        controller.start_at,
        controller.end_at,
        controller.grouping,
      ],
      ["custom", "2026-05-10", "2026-05-10", null, null, "hour"]
    );
  });

  test("choosing a date control clears the precise range", function (assert) {
    const controller = this.owner.lookup("controller:admin-site-traffic");
    controller.setPreciseRange(
      new Date("2026-05-10T10:03:00Z"),
      new Date("2026-05-10T10:06:00Z")
    );

    controller.setPeriod("last_7_days");

    assert.deepEqual(
      [controller.range, controller.start_at, controller.end_at],
      ["last_7_days", null, null],
      "a preset leaves no stale brush range"
    );
  });
});

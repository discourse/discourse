import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Controller | admin-site-traffic", function (hooks) {
  setupTest(hooks);

  test("a date preset does not change the interval", function (assert) {
    const controller = this.owner.lookup("controller:admin-site-traffic");
    controller.grouping = "hour";

    controller.setPeriod("last_7_days");

    assert.deepEqual(
      [
        controller.range,
        controller.start_date,
        controller.end_date,
        controller.grouping,
      ],
      ["last_7_days", null, null, "hour"],
      "the date range and graph interval remain independent"
    );
  });
});

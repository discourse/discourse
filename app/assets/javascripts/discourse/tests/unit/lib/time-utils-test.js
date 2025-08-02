import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  laterThisWeek,
  laterToday,
  nextMonth,
  startOfDay,
  tomorrow,
} from "discourse/lib/time-utils";
import { withFrozenTime } from "discourse/tests/helpers/qunit-helpers";

const timezone = "Australia/Brisbane";

module("Unit | lib | timeUtils", function (hooks) {
  setupTest(hooks);

  test("nextMonth gets next month correctly", function (assert) {
    withFrozenTime("2019-12-11T08:00:00", timezone, () => {
      assert.strictEqual(
        nextMonth(timezone).format("YYYY-MM-DD"),
        "2020-01-01"
      );
    });
  });

  test("laterThisWeek gets 2 days from now", function (assert) {
    withFrozenTime("2019-12-10T08:00:00", timezone, () => {
      assert.strictEqual(
        laterThisWeek(timezone).format("YYYY-MM-DD"),
        "2019-12-12"
      );
    });
  });

  test("tomorrow gets tomorrow correctly", function (assert) {
    withFrozenTime("2019-12-11T08:00:00", timezone, () => {
      assert.strictEqual(tomorrow(timezone).format("YYYY-MM-DD"), "2019-12-12");
    });
  });

  test("startOfDay changes the time of the provided date to 8:00am correctly", function (assert) {
    let dt = moment.tz("2019-12-11T11:37:16", timezone);

    assert.strictEqual(
      startOfDay(dt).format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 08:00:00"
    );
  });

  test("laterToday gets 3 hours from now and if before half-past, it rounds down", function (assert) {
    withFrozenTime("2019-12-11T08:13:00", timezone, () => {
      assert.strictEqual(
        laterToday(timezone).format("YYYY-MM-DD HH:mm:ss"),
        "2019-12-11 11:00:00"
      );
    });
  });

  test("laterToday gets 3 hours from now and if after half-past, it rounds up to the next hour", function (assert) {
    withFrozenTime("2019-12-11T08:43:00", timezone, () => {
      assert.strictEqual(
        laterToday(timezone).format("YYYY-MM-DD HH:mm:ss"),
        "2019-12-11 12:00:00"
      );
    });
  });

  test("laterToday is capped to 6pm. later today at 3pm = 6pm, 3:30pm = 6pm, 4pm = 6pm, 4:59pm = 6pm", function (assert) {
    withFrozenTime("2019-12-11T15:00:00", timezone, () => {
      assert.strictEqual(
        laterToday(timezone).format("YYYY-MM-DD HH:mm:ss"),
        "2019-12-11 18:00:00",
        "3pm should max to 6pm"
      );
    });

    withFrozenTime("2019-12-11T15:31:00", timezone, () => {
      assert.strictEqual(
        laterToday(timezone).format("YYYY-MM-DD HH:mm:ss"),
        "2019-12-11 18:00:00",
        "3:30pm should max to 6pm"
      );
    });

    withFrozenTime("2019-12-11T16:00:00", timezone, () => {
      assert.strictEqual(
        laterToday(timezone).format("YYYY-MM-DD HH:mm:ss"),
        "2019-12-11 18:00:00",
        "4pm should max to 6pm"
      );
    });

    withFrozenTime("2019-12-11T16:59:00", timezone, () => {
      assert.strictEqual(
        laterToday(timezone).format("YYYY-MM-DD HH:mm:ss"),
        "2019-12-11 18:00:00",
        "4:59pm should max to 6pm"
      );
    });
  });
});

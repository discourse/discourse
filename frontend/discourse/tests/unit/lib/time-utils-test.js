import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  adjustedRangeEnd,
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

  test("adjustedRangeEnd leaves a missing boundary alone", function (assert) {
    const from = moment("2026-07-01 10:00");

    assert.strictEqual(adjustedRangeEnd(null, null), null);
    assert.strictEqual(adjustedRangeEnd(from, null), null);
  });

  test("adjustedRangeEnd pushes an end at or before the start an hour past it", function (assert) {
    const from = moment("2026-07-01 10:00");

    assert.strictEqual(
      adjustedRangeEnd(from, from.clone()).format("HH:mm"),
      "11:00"
    );
    assert.strictEqual(
      adjustedRangeEnd(from, moment("2026-07-01 08:00")).format("HH:mm"),
      "11:00"
    );
  });

  test("adjustedRangeEnd keeps a valid end", function (assert) {
    const from = moment("2026-07-01 10:00");
    const to = moment("2026-07-01 12:00");

    assert.strictEqual(adjustedRangeEnd(from, to), to);
  });

  test("adjustedRangeEnd allows equal boundaries when dateOnly", function (assert) {
    const from = moment("2026-07-01");
    const to = moment("2026-07-01");

    assert.strictEqual(adjustedRangeEnd(from, to, { dateOnly: true }), to);
  });

  test("adjustedRangeEnd snaps an earlier end to the start day when dateOnly", function (assert) {
    const from = moment("2026-07-01");
    const to = moment("2026-06-20");

    assert.strictEqual(
      adjustedRangeEnd(from, to, { dateOnly: true }).format("YYYY-MM-DD"),
      "2026-07-01"
    );
  });

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

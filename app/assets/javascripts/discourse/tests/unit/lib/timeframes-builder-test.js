import { module, test } from "qunit";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import buildTimeframes from "discourse/lib/timeframes-builder";

const DEFAULT_OPTIONS = {
  includeWeekend: null,
  includeFarFuture: null,
  includeDateTime: null,
  canScheduleNow: false,
};

function buildOptions(now, opts) {
  return Object.assign(
    {},
    DEFAULT_OPTIONS,
    { now, day: now.day(), canScheduleToday: 24 - now.hour() > 6 },
    opts
  );
}

module("Unit | Lib | timeframes-builder", function (hooks) {
  hooks.afterEach(function () {
    if (this.clock) {
      this.clock.restore();
    }
  });

  test("default options", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-06-07T08:00:00", timezone, true); // Monday

    const expected = [
      "later_today",
      "tomorrow",
      "next_week",
      "two_weeks",
      "next_month",
      "two_months",
      "three_months",
      "four_months",
      "six_months",
    ];

    assert.deepEqual(
      buildTimeframes(buildOptions(moment())).mapBy("id"),
      expected
    );
  });

  test("doesn't output 'Next Week' on Sundays", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-06-13T08:00:00", timezone, true); // Sunday

    assert.ok(
      !buildTimeframes(buildOptions(moment())).mapBy("id").includes("next_week")
    );
  });

  test("outputs 'This Weekend' if it's enabled", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-06-07T08:00:00", timezone, true); // Monday

    assert.ok(
      buildTimeframes(buildOptions(moment(), { includeWeekend: true }))
        .mapBy("id")
        .includes("this_weekend")
    );
  });

  test("doesn't output 'This Weekend' on Fridays", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-23 18:00:00", timezone, true); // Friday

    assert.ok(
      !buildTimeframes(buildOptions(moment(), { includeWeekend: true }))
        .mapBy("id")
        .includes("this_weekend")
    );
  });

  test("doesn't show 'This Weekend' on Sundays", function (assert) {
    /*
      We need this test to avoid regressions.
      We tend to write such conditions and think that
      they mean the beginning of work week
      (Monday, Tuesday and Wednesday in this specific case):

       if (date.day <= 3) {
           ...
       }

      In fact, Sunday will pass this check too, because
      in moment.js 0 stands for Sunday.
    */

    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-25 18:00:00", timezone, true); // Sunday

    assert.ok(
      !buildTimeframes(buildOptions(moment(), { includeWeekend: true }))
        .mapBy("id")
        .includes("this_weekend")
    );
  });

  test("outputs 'Later This Week' instead of 'Later Today' at the end of the day", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-19 18:00:00", timezone, true); // Monday evening
    const timeframes = buildTimeframes(buildOptions(moment())).mapBy("id");

    assert.notOk(timeframes.includes("later_today"));
    assert.ok(timeframes.includes("later_this_week"));
  });

  test("doesn't output 'Later This Week' on Tuesdays", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-22 18:00:00", timezone, true); // Tuesday evening
    const timeframes = buildTimeframes(buildOptions(moment())).mapBy("id");

    assert.notOk(timeframes.includes("later_this_week"));
  });

  test("doesn't output 'Later This Week' on Sundays", function (assert) {
    /*
      We need this test to avoid regressions.
      We tend to write such conditions and think that
      they mean the beginning of business week
      (Monday, Tuesday and Wednesday in this specific case):

       if (date.day < 3) {
           ...
       }

      In fact, Sunday will pass this check too, because
      in moment.js 0 stands for Sunday.
    */
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-25 18:00:00", timezone, true); // Sunday evening
    const timeframes = buildTimeframes(buildOptions(moment())).mapBy("id");

    assert.notOk(timeframes.includes("later_this_week"));
  });

  test("doesn't output 'Next Month' on the last day of the month", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-30 18:00:00", timezone, true); // The last day of April
    const timeframes = buildTimeframes(buildOptions(moment())).mapBy("id");

    assert.notOk(timeframes.includes("next_month"));
  });
});

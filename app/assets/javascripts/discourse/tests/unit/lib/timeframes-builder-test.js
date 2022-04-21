import { module, test } from "qunit";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import buildTimeframes from "discourse/lib/timeframes-builder";

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
      "later_this_week",
      "start_of_next_business_week",
      "two_weeks",
      "next_month",
      "two_months",
      "three_months",
      "four_months",
      "six_months",
    ];

    assert.deepEqual(buildTimeframes(timezone).mapBy("id"), expected);
  });

  test("doesn't output 'Next Week' on Sundays", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-06-13T08:00:00", timezone, true); // Sunday

    assert.ok(
      !buildTimeframes(timezone)
        .mapBy("id")
        .includes("start_of_next_business_week")
    );
  });

  test("outputs 'This Weekend' if it's enabled", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-06-07T08:00:00", timezone, true); // Monday

    assert.ok(
      buildTimeframes(timezone, { includeWeekend: true })
        .mapBy("id")
        .includes("this_weekend")
    );
  });

  test("doesn't output 'This Weekend' on Fridays", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-23 18:00:00", timezone, true); // Friday

    assert.ok(
      !buildTimeframes(timezone, { includeWeekend: true })
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
      !buildTimeframes(timezone, { includeWeekend: true })
        .mapBy("id")
        .includes("this_weekend")
    );
  });

  test("outputs 'Later This Week' instead of 'Later Today' at the end of the day", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-19 18:00:00", timezone, true); // Monday evening
    const timeframes = buildTimeframes(timezone).mapBy("id");

    assert.notOk(timeframes.includes("later_today"));
    assert.ok(timeframes.includes("later_this_week"));
  });

  test("doesn't output 'Later This Week' on Thursdays", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-22 18:00:00", timezone, true); // Thursday evening
    const timeframes = buildTimeframes(timezone).mapBy("id");

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
    const timeframes = buildTimeframes(timezone).mapBy("id");

    assert.notOk(timeframes.includes("later_this_week"));
  });

  test("doesn't output 'Next Month' on the last day of the month", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-04-30 18:00:00", timezone, true); // The last day of April
    const timeframes = buildTimeframes(timezone).mapBy("id");

    assert.notOk(timeframes.includes("next_month"));
  });

  test("shows far future options if enabled", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-06-07T08:00:00", timezone, true); // Monday

    const timeframes = buildTimeframes(timezone, {
      includeFarFuture: true,
    }).mapBy("id");

    assert.ok(timeframes.includes("one_year"));
    assert.ok(timeframes.includes("forever"));
  });

  test("shows the pick-date-and-time option if enabled", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-06-07T08:00:00", timezone, true); // Monday

    const timeframes = buildTimeframes(timezone, {
      includeDateTime: true,
    }).mapBy("id");

    assert.ok(timeframes.includes("custom"));
  });

  test("shows the now option if enabled", function (assert) {
    const timezone = moment.tz.guess();
    this.clock = fakeTime("2100-06-07T08:00:00", timezone, true); // Monday

    const timeframes = buildTimeframes(timezone, {
      canScheduleNow: true,
    }).mapBy("id");

    assert.ok(timeframes.includes("now"));
  });
});

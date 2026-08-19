import { module, test } from "qunit";
import { hasIncompleteData } from "discourse/admin/components/admin-report-chart";
import { formatTimeScaleTick } from "discourse/admin/components/admin-report-stacked-chart";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | AdminReportChart", function (hooks) {
  setupRenderingTest(hooks);

  module("hasIncompleteData", function () {
    module("daily grouping", function () {
      test("returns true when last data point is today in UTC", function (assert) {
        const today = moment.utc().format("YYYY-MM-DD");

        assert.true(
          hasIncompleteData({ x: today, y: 5 }, "daily"),
          "should show incomplete styling when last point is today"
        );
      });

      test("returns false when last data point is yesterday in UTC", function (assert) {
        const yesterday = moment.utc().subtract(1, "day").format("YYYY-MM-DD");

        assert.false(
          hasIncompleteData({ x: yesterday, y: 5 }, "daily"),
          "should not show incomplete styling when last point is yesterday"
        );
      });
    });

    module("weekly grouping", function () {
      test("returns true when last data point is this week in UTC", function (assert) {
        const today = moment.utc().format("YYYY-MM-DD");

        assert.true(
          hasIncompleteData({ x: today, y: 5 }, "weekly"),
          "should show incomplete styling when last point is this week"
        );
      });

      test("returns false when last data point is last week in UTC", function (assert) {
        const lastWeek = moment.utc().subtract(1, "week").format("YYYY-MM-DD");

        assert.false(
          hasIncompleteData({ x: lastWeek, y: 5 }, "weekly"),
          "should not show incomplete styling when last point is last week"
        );
      });
    });

    module("monthly grouping", function () {
      test("returns true when last data point is this month in UTC", function (assert) {
        const today = moment.utc().format("YYYY-MM-DD");

        assert.true(
          hasIncompleteData({ x: today, y: 5 }, "monthly"),
          "should show incomplete styling when last point is this month"
        );
      });

      test("returns false when last data point is last month in UTC", function (assert) {
        const lastMonth = moment
          .utc()
          .subtract(1, "month")
          .format("YYYY-MM-DD");

        assert.false(
          hasIncompleteData({ x: lastMonth, y: 5 }, "monthly"),
          "should not show incomplete styling when last point is last month"
        );
      });
    });

    module("edge cases", function () {
      test("returns false for null point", function (assert) {
        assert.false(
          hasIncompleteData(null, "daily"),
          "should not show incomplete styling for null point"
        );
      });

      test("returns false for undefined point", function (assert) {
        assert.false(
          hasIncompleteData(undefined, "daily"),
          "should not show incomplete styling for undefined point"
        );
      });
    });
  });
});

module("Unit | Component | AdminReportStackedChart", function () {
  test("short hourly ranges label times and midnight boundaries", function (assert) {
    const options = {
      timeUnit: "hour",
      startDate: "2026-05-10T00:00:00Z",
      endDate: "2026-05-11T12:00:00Z",
    };

    assert.deepEqual(
      formatTimeScaleTick({ value: "2026-05-10T00:00:00Z", ...options }),
      ["10 May", "12:00 AM"]
    );
    assert.strictEqual(
      formatTimeScaleTick({ value: "2026-05-10T01:00:00Z", ...options }),
      "1:00 AM"
    );
  });

  test("the first hourly tick includes its date even when it is not midnight", function (assert) {
    assert.deepEqual(
      formatTimeScaleTick({
        value: "2026-05-10T02:00:00Z",
        timeUnit: "hour",
        startDate: "2026-05-10T01:33:00Z",
        endDate: "2026-05-11T01:33:00Z",
        isFirstTick: true,
      }),
      ["10 May", "2:00 AM"]
    );
  });

  test("long hourly ranges keep only day boundaries", function (assert) {
    const options = {
      timeUnit: "hour",
      startDate: "2026-04-12T00:00:00Z",
      endDate: "2026-05-12T00:00:00Z",
    };

    assert.strictEqual(
      formatTimeScaleTick({ value: "2026-05-10T00:00:00Z", ...options }),
      "10 May"
    );
    assert.strictEqual(
      formatTimeScaleTick({ value: "2026-05-10T01:00:00Z", ...options }),
      null
    );
  });

  test("daily ranges use localized month and day labels", function (assert) {
    assert.strictEqual(
      formatTimeScaleTick({
        value: "2026-05-10T00:00:00Z",
        timeUnit: "day",
      }),
      "10 May"
    );
  });

  test("daily ranges include years when they cross a year boundary", function (assert) {
    assert.strictEqual(
      formatTimeScaleTick({
        value: "2026-01-01T00:00:00Z",
        timeUnit: "day",
        startDate: "2025-12-20T00:00:00Z",
        endDate: "2026-01-10T00:00:00Z",
      }),
      "1 Jan 2026"
    );
  });
});

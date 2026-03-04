import { module, test } from "qunit";
import { hasIncompleteData } from "discourse/admin/components/admin-report-chart";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | admin-report-chart", function (hooks) {
  setupRenderingTest(hooks);

  module("hasIncompleteData", function () {
    module("daily grouping", function () {
      test("returns true when last data point is today", function (assert) {
        const today = moment().format("YYYY-MM-DD");

        assert.true(
          hasIncompleteData({ x: today, y: 5 }, "daily"),
          "should show incomplete styling when last point is today"
        );
      });

      test("returns false when last data point is yesterday", function (assert) {
        const yesterday = moment().subtract(1, "day").format("YYYY-MM-DD");

        assert.false(
          hasIncompleteData({ x: yesterday, y: 5 }, "daily"),
          "should not show incomplete styling when last point is yesterday"
        );
      });
    });

    module("weekly grouping", function () {
      test("returns true when last data point is this week", function (assert) {
        const today = moment().format("YYYY-MM-DD");

        assert.true(
          hasIncompleteData({ x: today, y: 5 }, "weekly"),
          "should show incomplete styling when last point is this week"
        );
      });

      test("returns false when last data point is last week", function (assert) {
        const lastWeek = moment().subtract(1, "week").format("YYYY-MM-DD");

        assert.false(
          hasIncompleteData({ x: lastWeek, y: 5 }, "weekly"),
          "should not show incomplete styling when last point is last week"
        );
      });
    });

    module("monthly grouping", function () {
      test("returns true when last data point is this month", function (assert) {
        const today = moment().format("YYYY-MM-DD");

        assert.true(
          hasIncompleteData({ x: today, y: 5 }, "monthly"),
          "should show incomplete styling when last point is this month"
        );
      });

      test("returns false when last data point is last month", function (assert) {
        const lastMonth = moment().subtract(1, "month").format("YYYY-MM-DD");

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

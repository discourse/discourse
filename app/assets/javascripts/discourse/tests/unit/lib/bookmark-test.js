import { module, test } from "qunit";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import { formattedReminderTime } from "discourse/lib/bookmark";

module("Unit | Utility | bookmark", function (hooks) {
  hooks.beforeEach(function () {
    this.clock = fakeTime("2020-04-11 08:00:00", "Australia/Brisbane");
  });

  hooks.afterEach(function () {
    this.clock.restore();
  });

  test("formattedReminderTime works when the reminder time is tomorrow", function (assert) {
    let reminderAt = "2020-04-12 09:45:00";
    let reminderAtDate = moment
      .tz(reminderAt, "Australia/Brisbane")
      .format("H:mm a");
    assert.equal(
      formattedReminderTime(reminderAt, "Australia/Brisbane"),
      "tomorrow at " + reminderAtDate
    );
  });

  test("formattedReminderTime works when the reminder time is today", function (assert) {
    let reminderAt = "2020-04-11 09:45:00";
    let reminderAtDate = moment
      .tz(reminderAt, "Australia/Brisbane")
      .format("H:mm a");
    assert.equal(
      formattedReminderTime(reminderAt, "Australia/Brisbane"),
      "today at " + reminderAtDate
    );
  });

  test("formattedReminderTime works when the reminder time is in the future", function (assert) {
    let reminderAt = "2020-04-15 09:45:00";
    let reminderAtDate = moment
      .tz(reminderAt, "Australia/Brisbane")
      .format("H:mm a");
    assert.equal(
      formattedReminderTime(reminderAt, "Australia/Brisbane"),
      "at Apr 15, 2020 " + reminderAtDate
    );
  });
});

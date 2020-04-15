import { formattedReminderTime } from "discourse/lib/bookmark";

QUnit.module("lib:bookmark", {
  beforeEach() {
    // set the current now time for all tests
    let now = moment.tz("2020-04-11T08:00:00", "Australia/Brisbane");
    sandbox.useFakeTimers(now.valueOf());
  }
});

QUnit.test(
  "formattedReminderTime works when the reminder time is tomorrow",
  assert => {
    let reminderAt = "2020-04-12T09:45:00";
    let reminderAtDate = moment(reminderAt)
      .tz("Australia/Brisbane")
      .format("H:mm a");
    assert.equal(
      formattedReminderTime(reminderAt, "Australia/Brisbane"),
      "tomorrow at " + reminderAtDate
    );
  }
);

QUnit.test(
  "formattedReminderTime works when the reminder time is today",
  assert => {
    let reminderAt = "2020-04-11T09:45:00";
    let reminderAtDate = moment(reminderAt)
      .tz("Australia/Brisbane")
      .format("H:mm a");
    assert.equal(
      formattedReminderTime(reminderAt, "Australia/Brisbane"),
      "today at " + reminderAtDate
    );
  }
);

QUnit.test(
  "formattedReminderTime works when the reminder time is in the future",
  assert => {
    let reminderAt = "2020-04-15T09:45:00";
    let reminderAtDate = moment(reminderAt)
      .tz("Australia/Brisbane")
      .format("H:mm a");
    assert.equal(
      formattedReminderTime(reminderAt, "Australia/Brisbane"),
      "at Apr 15, 2020 " + reminderAtDate
    );
  }
);

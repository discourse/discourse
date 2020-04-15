const timezone = "Australia/Brisbane";
import { formattedReminderTime } from "discourse/lib/bookmark";

QUnit.module("lib:bookmark", {
  beforeEach() {
    // set the current now time for all tests
    let now = moment.tz("2020-04-11T08:00:00", timezone);
    sandbox.useFakeTimers(now.valueOf());
  }
});

QUnit.test(
  "formattedReminderTime works when the reminder time is tomorrow",
  assert => {
    let reminderAt = "2020-04-12T09:45:00";
    assert.equal(
      formattedReminderTime(reminderAt, timezone),
      "tomorrow at 9:45 am"
    );
  }
);

QUnit.test(
  "formattedReminderTime works when the reminder time is today",
  assert => {
    let reminderAt = "2020-04-11T09:45:00";
    assert.equal(
      formattedReminderTime(reminderAt, timezone),
      "today at 9:45 am"
    );
  }
);

QUnit.test(
  "formattedReminderTime works when the reminder time is in the future",
  assert => {
    let reminderAt = "2020-04-15T09:45:00";
    assert.equal(
      formattedReminderTime(reminderAt, timezone),
      "at Apr 15, 2020 9:45 am"
    );
  }
);

import { logIn } from "helpers/qunit-helpers";
import User from "discourse/models/user";
let BookmarkController;

moduleFor("controller:bookmark", {
  beforeEach() {
    logIn();
    BookmarkController = this.subject({ currentUser: User.current() });
  },

  afterEach() {
    sandbox.restore();
  }
});

function mockMomentTz(dateString) {
  let now = moment.tz(dateString, BookmarkController.userTimezone);
  sandbox.useFakeTimers(now.valueOf());
}

QUnit.test("showLaterToday when later today is tomorrow do not show", function(
  assert
) {
  mockMomentTz("2019-12-11T22:00:00");

  assert.equal(BookmarkController.get("showLaterToday"), false);
});

QUnit.test("showLaterToday when later today is after 5pm", function(assert) {
  mockMomentTz("2019-12-11T15:00:00");
  assert.equal(BookmarkController.get("showLaterToday"), false);
});

QUnit.test(
  "showLaterToday when later today is before the end of the day, show",
  function(assert) {
    mockMomentTz("2019-12-11T10:00:00");

    assert.equal(BookmarkController.get("showLaterToday"), true);
  }
);

QUnit.test("nextWeek gets next week correctly", function(assert) {
  mockMomentTz("2019-12-11T08:00:00");

  assert.equal(
    BookmarkController.nextWeek().format("YYYY-MM-DD"),
    "2019-12-18"
  );
});

QUnit.test("nextMonth gets next month correctly", function(assert) {
  mockMomentTz("2019-12-11T08:00:00");

  assert.equal(
    BookmarkController.nextMonth().format("YYYY-MM-DD"),
    "2020-01-11"
  );
});

QUnit.test(
  "nextBusinessDay gets next business day of monday correctly if today is friday",
  function(assert) {
    mockMomentTz("2019-12-13T08:00:00");

    assert.equal(
      BookmarkController.nextBusinessDay().format("YYYY-MM-DD"),
      "2019-12-16"
    );
  }
);

QUnit.test(
  "nextBusinessDay gets next business day of monday correctly if today is saturday",
  function(assert) {
    mockMomentTz("2019-12-14T08:00:00");

    assert.equal(
      BookmarkController.nextBusinessDay().format("YYYY-MM-DD"),
      "2019-12-16"
    );
  }
);

QUnit.test(
  "nextBusinessDay gets next business day of monday correctly if today is sunday",
  function(assert) {
    mockMomentTz("2019-12-15T08:00:00");

    assert.equal(
      BookmarkController.nextBusinessDay().format("YYYY-MM-DD"),
      "2019-12-16"
    );
  }
);

QUnit.test(
  "nextBusinessDay gets next business day of thursday correctly if today is wednesday",
  function(assert) {
    mockMomentTz("2019-12-11T08:00:00");

    assert.equal(
      BookmarkController.nextBusinessDay().format("YYYY-MM-DD"),
      "2019-12-12"
    );
  }
);

QUnit.test("tomorrow gets tomorrow correctly", function(assert) {
  mockMomentTz("2019-12-11T08:00:00");

  assert.equal(
    BookmarkController.tomorrow().format("YYYY-MM-DD"),
    "2019-12-12"
  );
});

QUnit.test(
  "startOfDay changes the time of the provided date to 8:00am correctly",
  function(assert) {
    let dt = moment.tz(
      "2019-12-11T11:37:16",
      BookmarkController.currentUser.resolvedTimezone()
    );

    assert.equal(
      BookmarkController.startOfDay(dt).format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 08:00:00"
    );
  }
);

QUnit.test(
  "laterToday gets 3 hours from now and if before half-past, it sets the time to half-past",
  function(assert) {
    mockMomentTz("2019-12-11T08:13:00");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 11:30:00"
    );
  }
);

QUnit.test(
  "laterToday gets 3 hours from now and if after half-past, it rounds up to the next hour",
  function(assert) {
    mockMomentTz("2019-12-11T08:43:00");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 12:00:00"
    );
  }
);

QUnit.test(
  "loadLastUsedCustomReminderDatetime fills the custom reminder date + time if present in localStorage",
  function(assert) {
    mockMomentTz("2019-12-11T08:00:00");
    localStorage.lastCustomBookmarkReminderDate = "2019-12-12";
    localStorage.lastCustomBookmarkReminderTime = "08:00";

    BookmarkController.loadLastUsedCustomReminderDatetime();

    assert.equal(BookmarkController.lastCustomReminderDate, "2019-12-12");
    assert.equal(BookmarkController.lastCustomReminderTime, "08:00");
  }
);

QUnit.test(
  "loadLastUsedCustomReminderDatetime does not fills the custom reminder date + time if the datetime in localStorage is < now",
  function(assert) {
    mockMomentTz("2019-12-11T08:00:00");
    localStorage.lastCustomBookmarkReminderDate = "2019-12-11";
    localStorage.lastCustomBookmarkReminderTime = "07:00";

    BookmarkController.loadLastUsedCustomReminderDatetime();

    assert.equal(BookmarkController.lastCustomReminderDate, null);
    assert.equal(BookmarkController.lastCustomReminderTime, null);
  }
);

QUnit.test("user timezone updates when the modal is shown", function(assert) {
  User.current().changeTimezone(null);
  let stub = sandbox.stub(moment.tz, "guess").returns("Europe/Moscow");
  BookmarkController.onShow();
  assert.equal(BookmarkController.userHasTimezoneSet, true);
  assert.equal(
    BookmarkController.userTimezone,
    "Europe/Moscow",
    "the user does not have their timezone set and a timezone is guessed"
  );
  User.current().changeTimezone("Australia/Brisbane");
  BookmarkController.onShow();
  assert.equal(BookmarkController.userHasTimezoneSet, true);
  assert.equal(
    BookmarkController.userTimezone,
    "Australia/Brisbane",
    "the user does their timezone set"
  );
  stub.restore();
});

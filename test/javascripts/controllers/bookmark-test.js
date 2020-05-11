import { logIn } from "helpers/qunit-helpers";
import User from "discourse/models/user";
import KeyboardShortcutInitializer from "discourse/initializers/keyboard-shortcuts";
import { REMINDER_TYPES } from "discourse/lib/bookmark";
import { fakeTime } from "helpers/qunit-helpers";
let BookmarkController;

moduleFor("controller:bookmark", {
  beforeEach() {
    logIn();
    KeyboardShortcutInitializer.initialize(Discourse.__container__);
    BookmarkController = this.subject({ currentUser: User.current() });
    BookmarkController.onShow();
  },

  afterEach() {
    sandbox.restore();
  }
});

function mockMomentTz(dateString) {
  fakeTime(dateString, BookmarkController.userTimezone);
}

QUnit.test("showLaterToday when later today is tomorrow do not show", function(
  assert
) {
  mockMomentTz("2019-12-11T22:00:00");

  assert.equal(BookmarkController.get("showLaterToday"), false);
});

QUnit.test(
  "showLaterToday when later today is after 5pm but before 6pm",
  function(assert) {
    mockMomentTz("2019-12-11T15:00:00");
    assert.equal(BookmarkController.get("showLaterToday"), true);
  }
);

QUnit.test("showLaterToday when now is after the cutoff time (5pm)", function(
  assert
) {
  mockMomentTz("2019-12-11T17:00:00");
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

QUnit.test("laterThisWeek gets 2 days from now", function(assert) {
  mockMomentTz("2019-12-10T08:00:00");

  assert.equal(
    BookmarkController.laterThisWeek().format("YYYY-MM-DD"),
    "2019-12-12"
  );
});

QUnit.test("laterThisWeek returns null if we are at Thursday already", function(
  assert
) {
  mockMomentTz("2019-12-12T08:00:00");

  assert.equal(BookmarkController.laterThisWeek(), null);
});

QUnit.test("showLaterThisWeek returns true if < Thursday", function(assert) {
  mockMomentTz("2019-12-10T08:00:00");

  assert.equal(BookmarkController.showLaterThisWeek, true);
});

QUnit.test("showLaterThisWeek returns false if > Thursday", function(assert) {
  mockMomentTz("2019-12-12T08:00:00");

  assert.equal(BookmarkController.showLaterThisWeek, false);
});
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
      BookmarkController.currentUser.resolvedTimezone(
        BookmarkController.currentUser
      )
    );

    assert.equal(
      BookmarkController.startOfDay(dt).format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 08:00:00"
    );
  }
);

QUnit.test(
  "laterToday gets 3 hours from now and if before half-past, it rounds down",
  function(assert) {
    mockMomentTz("2019-12-11T08:13:00");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 11:00:00"
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
  "laterToday is capped to 6pm. later today at 3pm = 6pm, 3:30pm = 6pm, 4pm = 6pm, 4:59pm = 6pm",
  function(assert) {
    mockMomentTz("2019-12-11T15:00:00");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 18:00:00",
      "3pm should max to 6pm"
    );

    mockMomentTz("2019-12-11T15:31:00");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 18:00:00",
      "3:30pm should max to 6pm"
    );

    mockMomentTz("2019-12-11T16:00:00");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 18:00:00",
      "4pm should max to 6pm"
    );

    mockMomentTz("2019-12-11T16:59:00");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 18:00:00",
      "4:59pm should max to 6pm"
    );
  }
);

QUnit.test("showLaterToday returns false if >= 5PM", function(assert) {
  mockMomentTz("2019-12-11T17:00:01");
  assert.equal(BookmarkController.showLaterToday, false);
});

QUnit.test("showLaterToday returns false if >= 5PM", function(assert) {
  mockMomentTz("2019-12-11T17:00:01");
  assert.equal(BookmarkController.showLaterToday, false);
});

QUnit.test(
  "reminderAt - custom - defaults to 8:00am if the time is not selected",
  function(assert) {
    BookmarkController.customReminderDate = "2028-12-12";
    BookmarkController.selectedReminderType =
      BookmarkController.reminderTypes.CUSTOM;
    const reminderAt = BookmarkController._reminderAt();
    assert.equal(BookmarkController.customReminderTime, "08:00");
    assert.equal(
      reminderAt.toString(),
      moment
        .tz(
          "2028-12-12 08:00",
          BookmarkController.currentUser.resolvedTimezone(
            BookmarkController.currentUser
          )
        )
        .toString(),
      "the custom date and time are parsed correctly with default time"
    );
  }
);

QUnit.test(
  "loadLastUsedCustomReminderDatetime fills the custom reminder date + time if present in localStorage",
  function(assert) {
    mockMomentTz("2019-12-11T08:00:00");
    localStorage.lastCustomBookmarkReminderDate = "2019-12-12";
    localStorage.lastCustomBookmarkReminderTime = "08:00";

    BookmarkController._loadLastUsedCustomReminderDatetime();

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

    BookmarkController._loadLastUsedCustomReminderDatetime();

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

QUnit.test(
  "opening the modal with an existing bookmark with reminder at prefills the custom reminder type",
  function(assert) {
    let name = "test";
    let reminderAt = "2020-05-15T09:45:00";
    BookmarkController.model = { id: 1, name: name, reminderAt: reminderAt };
    BookmarkController.onShow();
    assert.equal(
      BookmarkController.selectedReminderType,
      REMINDER_TYPES.CUSTOM
    );
    assert.equal(BookmarkController.customReminderDate, "2020-05-15");
    assert.equal(BookmarkController.customReminderTime, "09:45");
    assert.equal(BookmarkController.model.name, name);
  }
);

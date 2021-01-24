import {
  discourseModule,
  fakeTime,
  logIn,
} from "discourse/tests/helpers/qunit-helpers";
import KeyboardShortcutInitializer from "discourse/initializers/keyboard-shortcuts";
import User from "discourse/models/user";
import { getApplication } from "@ember/test-helpers";
import sinon from "sinon";
import { test } from "qunit";

let BookmarkController;

function mockMomentTz(dateString) {
  fakeTime(dateString, BookmarkController.userTimezone);
}

discourseModule("Unit | Controller | bookmark", function (hooks) {
  hooks.beforeEach(function () {
    logIn();
    KeyboardShortcutInitializer.initialize(getApplication());

    BookmarkController = this.owner.lookup("controller:bookmark");
    BookmarkController.setProperties({
      currentUser: User.current(),
      site: { isMobileDevice: false },
    });
    BookmarkController.onShow();
  });

  hooks.afterEach(function () {
    sinon.restore();
  });
  // test("showLaterThisWeek returns true if < Thursday", function (assert) {
  //   mockMomentTz("2019-12-10T08:00:00");

  //   assert.equal(showLaterThisWeek(), true);
  // });

  test("showLaterToday when later today is tomorrow do not show", function (assert) {
    mockMomentTz("2019-12-11T22:00:00");

    assert.equal(BookmarkController.get("showLaterToday"), false);
  });

  test("showLaterToday when later today is after 5pm but before 6pm", function (assert) {
    mockMomentTz("2019-12-11T15:00:00");
    assert.equal(BookmarkController.get("showLaterToday"), true);
  });

  test("showLaterToday when now is after the cutoff time (5pm)", function (assert) {
    mockMomentTz("2019-12-11T17:00:00");
    assert.equal(BookmarkController.get("showLaterToday"), false);
  });

  test("showLaterToday when later today is before the end of the day, show", function (assert) {
    mockMomentTz("2019-12-11T10:00:00");

    assert.equal(BookmarkController.get("showLaterToday"), true);
  });

  test("showLaterThisWeek returns false if > Thursday", function (assert) {
    mockMomentTz("2019-12-12T08:00:00");

    assert.equal(BookmarkController.showLaterThisWeek, false);
  });

  test("showLaterToday returns false if >= 5PM", function (assert) {
    mockMomentTz("2019-12-11T17:00:01");
    assert.equal(BookmarkController.showLaterToday, false);
  });

  test("showLaterToday returns false if >= 5PM", function (assert) {
    mockMomentTz("2019-12-11T17:00:01");
    assert.equal(BookmarkController.showLaterToday, false);
  });

  // test("reminderAt - custom - defaults to 8:00am if the time is not selected", function (assert) {
  //   BookmarkController.customReminderDate = "2028-12-12";
  //   BookmarkController.selectedReminderType = "custom";
  //   const reminderAt = BookmarkController._reminderAt();
  //   assert.equal(BookmarkController.customReminderTime, "08:00");
  //   assert.equal(
  //     reminderAt.toString(),
  //     moment
  //       .tz(
  //         "2028-12-12 08:00",
  //         BookmarkController.currentUser.resolvedTimezone(
  //           BookmarkController.currentUser
  //         )
  //       )
  //       .toString(),
  //     "the custom date and time are parsed correctly with default time"
  //   );
  // });

  // test("loadLastUsedCustomReminderDatetime fills the custom reminder date + time if present in localStorage", function (assert) {
  //   mockMomentTz("2019-12-11T08:00:00");
  //   localStorage.lastCustomBookmarkReminderDate = "2019-12-12";
  //   localStorage.lastCustomBookmarkReminderTime = "08:00";

  //   BookmarkController._loadLastUsedCustomReminderDatetime();

  //   assert.equal(BookmarkController.lastCustomReminderDate, "2019-12-12");
  //   assert.equal(BookmarkController.lastCustomReminderTime, "08:00");
  // });

  // test("loadLastUsedCustomReminderDatetime does not fills the custom reminder date + time if the datetime in localStorage is < now", function (assert) {
  //   mockMomentTz("2019-12-11T08:00:00");
  //   localStorage.lastCustomBookmarkReminderDate = "2019-12-11";
  //   localStorage.lastCustomBookmarkReminderTime = "07:00";

  //   BookmarkController._loadLastUsedCustomReminderDatetime();

  //   assert.equal(BookmarkController.lastCustomReminderDate, null);
  //   assert.equal(BookmarkController.lastCustomReminderTime, null);
  // });

  test("user timezone updates when the modal is shown", function (assert) {
    User.current().changeTimezone(null);
    let stub = sinon.stub(moment.tz, "guess").returns("Europe/Moscow");
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

  test("opening the modal with an existing bookmark with reminder at prefills the custom reminder type", function (assert) {
    let name = "test";
    let reminderAt = "2020-05-15T09:45:00";
    BookmarkController.model = { id: 1, name: name, reminderAt: reminderAt };
    BookmarkController.onShow();
    assert.equal(BookmarkController.prefilledDatetime, "2020-05-15T09:45:00");
    assert.equal(BookmarkController.model.name, name);
  });
});

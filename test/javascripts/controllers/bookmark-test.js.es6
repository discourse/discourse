import { currentUser } from "helpers/qunit-helpers";
let BookmarkController;

moduleFor("controller:bookmark", {
  beforeEach() {
    BookmarkController = this.subject({ currentUser: currentUser() });
  },

  afterEach() {
    sandbox.restore();
  }
});

function mockMomentTz(dateString) {
  let now = moment.tz(dateString, BookmarkController.currentUser.timezone);
  sandbox.useFakeTimers(now.valueOf());
}

QUnit.test("showLaterToday when later today is tomorrow do not show", function(
  assert
) {
  mockMomentTz("2019-12-11T13:00:00Z");

  assert.equal(BookmarkController.get("showLaterToday"), false);
});

QUnit.test(
  "showLaterToday when later today is before the end of the day, show",
  function(assert) {
    mockMomentTz("2019-12-11T08:00:00Z");

    assert.equal(BookmarkController.get("showLaterToday"), true);
  }
);

QUnit.test("nextWeek gets next week correctly", function(assert) {
  mockMomentTz("2019-12-11T08:00:00Z");

  assert.equal(
    BookmarkController.nextWeek().format("YYYY-MM-DD"),
    "2019-12-18"
  );
});

QUnit.test("nextMonth gets next month correctly", function(assert) {
  mockMomentTz("2019-12-11T08:00:00Z");

  assert.equal(
    BookmarkController.nextMonth().format("YYYY-MM-DD"),
    "2020-01-11"
  );
});

QUnit.test(
  "nextBusinessDay gets next business day of monday correctly if today is friday",
  function(assert) {
    mockMomentTz("2019-12-13T08:00:00Z");

    assert.equal(
      BookmarkController.nextBusinessDay().format("YYYY-MM-DD"),
      "2019-12-16"
    );
  }
);

QUnit.test(
  "nextBusinessDay gets next business day of monday correctly if today is saturday",
  function(assert) {
    mockMomentTz("2019-12-14T08:00:00Z");

    assert.equal(
      BookmarkController.nextBusinessDay().format("YYYY-MM-DD"),
      "2019-12-16"
    );
  }
);

QUnit.test(
  "nextBusinessDay gets next business day of monday correctly if today is sunday",
  function(assert) {
    mockMomentTz("2019-12-15T08:00:00Z");

    assert.equal(
      BookmarkController.nextBusinessDay().format("YYYY-MM-DD"),
      "2019-12-16"
    );
  }
);

QUnit.test(
  "nextBusinessDay gets next business day of thursday correctly if today is wednesday",
  function(assert) {
    mockMomentTz("2019-12-11T08:00:00Z");

    assert.equal(
      BookmarkController.nextBusinessDay().format("YYYY-MM-DD"),
      "2019-12-12"
    );
  }
);

QUnit.test("tomorrow gets tomorrow correctly", function(assert) {
  mockMomentTz("2019-12-11T08:00:00Z");

  assert.equal(
    BookmarkController.tomorrow().format("YYYY-MM-DD"),
    "2019-12-12"
  );
});

QUnit.test(
  "startOfDay changes the time of the provided date to 8:00am correctly",
  function(assert) {
    let dt = moment.tz(
      "2019-12-11T11:37:16Z",
      BookmarkController.currentUser.timezone
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
    mockMomentTz("2019-12-11T08:13:00Z");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 21:30:00"
    );
  }
);

QUnit.test(
  "laterToday gets 3 hours from now and if after half-past, it rounds up to the next hour",
  function(assert) {
    mockMomentTz("2019-12-11T08:43:00Z");

    assert.equal(
      BookmarkController.laterToday().format("YYYY-MM-DD HH:mm:ss"),
      "2019-12-11 22:00:00"
    );
  }
);

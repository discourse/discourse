import I18n from "I18n";
import LocalDateBuilder from "./local-date-builder";
import sinon from "sinon";
import QUnit, { module, test } from "qunit";

const UTC = "Etc/UTC";
const SYDNEY = "Australia/Sydney";
const LOS_ANGELES = "America/Los_Angeles";
const NEW_YORK = "America/New_York";
const PARIS = "Europe/Paris";
const LAGOS = "Africa/Lagos";
const LONDON = "Europe/London";

module("lib:local-date-builder");

function freezeTime({ date, timezone }, cb) {
  date = date || "2020-01-22 10:34";
  const newTimezone = timezone || PARIS;
  const previousZone = moment.tz.guess();
  const now = moment.tz(date, newTimezone).valueOf();

  sinon.useFakeTimers(now);
  sinon.stub(moment.tz, "guess");
  moment.tz.guess.returns(newTimezone);
  moment.tz.setDefault(newTimezone);

  cb();

  moment.tz.guess.returns(previousZone);
  moment.tz.setDefault(previousZone);
  sinon.restore();
}

QUnit.assert.buildsCorrectDate = function (options, expected, message) {
  const localTimezone = options.localTimezone || PARIS;
  delete options.localTimezone;

  const localDateBuilder = new LocalDateBuilder(
    Object.assign(
      {},
      {
        date: "2020-03-22",
      },
      options
    ),
    localTimezone
  );

  if (expected.formated) {
    this.test.assert.strictEqual(
      localDateBuilder.build().formated,
      expected.formated,
      message || "it formates the date correctly"
    );
  }

  if (expected.previews) {
    this.test.assert.deepEqual(
      localDateBuilder.build().previews,
      expected.previews,
      message || "it formates the previews correctly"
    );
  }
};

test("date", function (assert) {
  freezeTime({ date: "2020-03-11" }, () => {
    assert.buildsCorrectDate(
      { date: "2020-03-22", timezone: PARIS },
      { formated: "March 22, 2020" },
      "it displays the date without time"
    );
  });
});

test("date and time", function (assert) {
  assert.buildsCorrectDate(
    { date: "2020-04-11", time: "11:00" },
    { formated: "April 11, 2020 1:00 PM" },
    "it displays the date with time"
  );

  assert.buildsCorrectDate(
    { date: "2020-04-11", time: "11:05:12", format: "LTS" },
    { formated: "1:05:12 PM" },
    "it displays full time (hours, minutes, seconds)"
  );
});

test("option[format]", function (assert) {
  freezeTime({ date: "2020-03-11" }, () => {
    assert.buildsCorrectDate(
      { format: "YYYY" },
      { formated: "2020 (UTC)" },
      "it uses custom format"
    );
  });
});

test("option[displayedTimezone]", function (assert) {
  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { displayedTimezone: SYDNEY },
      { formated: "March 22, 2020 (Sydney)" },
      "it displays the timezone if the timezone is different from the date"
    );
  });

  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { displayedTimezone: PARIS, timezone: PARIS },
      { formated: "March 22, 2020" },
      "it doesn't display the timezone if the timezone is the same than the date"
    );
  });

  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { timezone: UTC, displayedTimezone: UTC },
      { formated: "March 22, 2020 (UTC)" },
      "it replaces `Etc/`"
    );
  });

  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { timezone: LOS_ANGELES, displayedTimezone: LOS_ANGELES },
      { formated: "March 22, 2020 (Los Angeles)" },
      "it removes prefix and replaces `_`"
    );
  });
});

test("option[timezone]", function (assert) {
  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { timezone: SYDNEY, displayedTimezone: PARIS },
      { formated: "March 21, 2020" },
      "it correctly parses a date with the given timezone context"
    );
  });
});

test("option[recurring]", function (assert) {
  freezeTime({ date: "2020-04-06 06:00", timezone: LAGOS }, () => {
    assert.buildsCorrectDate(
      {
        date: "2019-11-25",
        time: "11:00",
        timezone: PARIS,
        displayedTimezone: LAGOS,
        recurring: "1.weeks",
      },
      {
        formated: "April 6, 2020 10:00 AM (Lagos)",
      },
      "it correctly formats a recurring date starting from a !isDST timezone to a isDST timezone date when displayed to a user using a timezone with no DST"
    );
  });

  freezeTime({ date: "2020-04-06 01:00", timezone: SYDNEY }, () => {
    assert.buildsCorrectDate(
      {
        date: "2020-03-09",
        time: "02:00",
        timezone: UTC,
        recurring: "1.weeks",
        calendar: false,
        displayedTimezone: SYDNEY,
      },
      {
        formated: "April 6, 2020 12:00 PM (Sydney)",
      },
      "it correctly formats a recurring date spanning over weeks"
    );
  });

  freezeTime({ date: "2020-04-07 22:00" }, () => {
    assert.buildsCorrectDate(
      {
        date: "2019-11-25",
        time: "11:00",
        recurring: "1.weeks",
        timezone: PARIS,
      },
      {
        formated: "April 13, 2020 11:00 AM",
      },
      "it correctly adds from a !isDST date to a isDST date"
    );
  });

  freezeTime({ date: "2020-04-06 10:59" }, () => {
    assert.buildsCorrectDate(
      {
        date: "2020-03-30",
        time: "11:00",
        recurring: "1.weeks",
        timezone: PARIS,
      },
      {
        formated: "Today 11:00 AM",
      },
      "it works to the minute"
    );
  });

  freezeTime({ date: "2020-04-06 11:01" }, () => {
    assert.buildsCorrectDate(
      {
        date: "2020-03-30",
        time: "11:00",
        recurring: "1.weeks",
        timezone: PARIS,
      },
      {
        formated: "April 13, 2020 11:00 AM",
      },
      "it works to the minute"
    );
  });

  freezeTime({ date: "2020-12-28 09:16" }, () => {
    assert.buildsCorrectDate(
      {
        date: "2021-01-24",
        time: "08:30",
        recurring: "1.weeks",
        timezone: NEW_YORK,
      },
      {
        formated: "January 24, 2021 2:30 PM",
      },
      "it works for a future date"
    );
  });

  freezeTime({ date: "2021-01-08 11:16" }, () => {
    assert.buildsCorrectDate(
      {
        date: "2021-01-05",
        time: "14:00",
        recurring: "2.hours",
        timezone: NEW_YORK,
      },
      {
        formated: "Today 12:00 PM",
      },
      "it works with hours"
    );
  });
});

test("option[countown]", function (assert) {
  freezeTime({ date: "2020-03-21 23:59" }, () => {
    assert.buildsCorrectDate(
      {
        countdown: true,
        timezone: PARIS,
      },
      { formated: "a minute" },
      "it shows the time remaining"
    );
  });

  freezeTime({ date: "2020-03-22 00:01" }, () => {
    assert.buildsCorrectDate(
      {
        countdown: true,
        timezone: PARIS,
      },
      {
        formated: I18n.t(
          "discourse_local_dates.relative_dates.countdown.passed"
        ),
      },
      "it shows the date has passed"
    );
  });
});

test("option[calendar]", function (assert) {
  freezeTime({ date: "2020-03-23 23:00" }, () => {
    assert.buildsCorrectDate(
      { date: "2020-03-22", time: "23:59", timezone: PARIS },
      { formated: "Yesterday 11:59 PM" },
      "it drops calendar mode when event date is more than one day before current date"
    );
  });

  freezeTime({ date: "2020-03-20 23:59" }, () =>
    assert.buildsCorrectDate(
      { date: "2020-03-21", time: "01:00", timezone: PARIS },
      { formated: "Tomorrow 1:00 AM" }
    )
  );

  freezeTime({ date: "2020-03-20 23:59" }, () =>
    assert.buildsCorrectDate(
      { date: "2020-03-21", time: "00:00", timezone: PARIS },
      { formated: "Saturday" },
      "it displays the day with no time when the time in the displayed timezone is 00:00"
    )
  );

  freezeTime({ date: "2020-03-20 23:59" }, () => {
    assert.buildsCorrectDate(
      { date: "2020-03-21", time: "23:59", timezone: PARIS },
      { formated: "Tomorrow 11:59 PM" }
    );
  });

  freezeTime({ date: "2020-03-21 00:00" }, () =>
    assert.buildsCorrectDate(
      { date: "2020-03-21", time: "23:00", timezone: PARIS },
      { formated: "Today 11:00 PM" }
    )
  );

  freezeTime({ date: "2020-03-22 23:59" }, () =>
    assert.buildsCorrectDate(
      { date: "2020-03-21", time: "23:59", timezone: PARIS },
      { formated: "Yesterday 11:59 PM" }
    )
  );

  freezeTime({ date: "2020-03-22 23:59" }, () =>
    assert.buildsCorrectDate(
      { date: "2020-03-21", time: "23:59", timezone: PARIS },
      { formated: "Yesterday 11:59 PM" }
    )
  );

  freezeTime({ date: "2020-03-22 23:59" }, () =>
    assert.buildsCorrectDate(
      { calendar: false, date: "2020-03-21", time: "23:59", timezone: PARIS },
      { formated: "March 21, 2020 11:59 PM" },
      "it doesn't use calendar when disabled"
    )
  );

  freezeTime({ date: "2020-03-24 01:00" }, () =>
    assert.buildsCorrectDate(
      { date: "2020-03-21", timezone: PARIS },
      { formated: "March 21, 2020" },
      "it stops formating out of calendar range"
    )
  );

  freezeTime({ date: "2020-05-12", timezone: LOS_ANGELES }, () => {
    assert.buildsCorrectDate(
      {
        date: "2020-05-13",
        time: "18:00",
        localTimezone: LOS_ANGELES,
      },
      { formated: "Tomorrow 11:00 AM" },
      "it correctly displays a different local timezone"
    );
  });
});

test("previews", function (assert) {
  freezeTime({ date: "2020-03-22" }, () => {
    assert.buildsCorrectDate(
      { timezone: PARIS },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Paris",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { timezone: PARIS, timezones: [SYDNEY] },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Paris",
          },
          {
            formated:
              "Sunday, March 22, 2020 10:00 AM → Monday, March 23, 2020 10:00 AM",
            timezone: "Sydney",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { timezone: PARIS, displayedTimezone: LOS_ANGELES },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Paris",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { timezone: PARIS, isplayedTimezone: PARIS },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Paris",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { timezone: PARIS, timezones: [PARIS] },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Paris",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { duration: 90, timezone: PARIS, timezones: [PARIS] },
      {
        previews: [
          {
            current: true,
            formated:
              'Sunday, March 22, 2020 <br /><svg class=\'fa d-icon d-icon-clock svg-icon svg-string\' xmlns="http://www.w3.org/2000/svg"><use href="#clock" /></svg> 12:00 AM → 1:30 AM',
            timezone: "Paris",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { duration: 1440, timezone: PARIS, timezones: [PARIS] },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Paris",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { time: "11:34", timezone: PARIS, timezones: [PARIS] },
      {
        previews: [
          {
            current: true,
            formated:
              'Sunday, March 22, 2020 <br /><svg class=\'fa d-icon d-icon-clock svg-icon svg-string\' xmlns="http://www.w3.org/2000/svg"><use href="#clock" /></svg> 11:34 AM',
            timezone: "Paris",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-04-06", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      {
        timezone: PARIS,
        date: "2020-04-07",
        timezones: [LONDON, LAGOS, SYDNEY],
      },
      {
        previews: [
          {
            current: true,
            formated:
              "Tuesday, April 7, 2020 12:00 AM → Wednesday, April 8, 2020 12:00 AM",
            timezone: "Paris",
          },
          {
            formated:
              "Monday, April 6, 2020 11:00 PM → Tuesday, April 7, 2020 11:00 PM",
            timezone: "London",
          },
          {
            formated:
              "Monday, April 6, 2020 11:00 PM → Tuesday, April 7, 2020 11:00 PM",
            timezone: "Lagos",
          },
          {
            formated:
              "Tuesday, April 7, 2020 8:00 AM → Wednesday, April 8, 2020 8:00 AM",
            timezone: "Sydney",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-04-06", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      {
        timezone: PARIS,
        date: "2020-04-07",
        time: "14:54",
        timezones: [LONDON, LAGOS, SYDNEY],
      },
      {
        previews: [
          {
            current: true,
            formated:
              'Tuesday, April 7, 2020 <br /><svg class=\'fa d-icon d-icon-clock svg-icon svg-string\' xmlns="http://www.w3.org/2000/svg"><use href="#clock" /></svg> 2:54 PM',
            timezone: "Paris",
          },
          {
            formated:
              'Tuesday, April 7, 2020 <br /><svg class=\'fa d-icon d-icon-clock svg-icon svg-string\' xmlns="http://www.w3.org/2000/svg"><use href="#clock" /></svg> 1:54 PM',
            timezone: "London",
          },
          {
            formated:
              'Tuesday, April 7, 2020 <br /><svg class=\'fa d-icon d-icon-clock svg-icon svg-string\' xmlns="http://www.w3.org/2000/svg"><use href="#clock" /></svg> 1:54 PM',
            timezone: "Lagos",
          },
          {
            formated:
              'Tuesday, April 7, 2020 <br /><svg class=\'fa d-icon d-icon-clock svg-icon svg-string\' xmlns="http://www.w3.org/2000/svg"><use href="#clock" /></svg> 10:54 PM',
            timezone: "Sydney",
          },
        ],
      }
    );
  });

  freezeTime({ date: "2020-05-12", timezone: LOS_ANGELES }, () => {
    assert.buildsCorrectDate(
      {
        date: "2020-05-13",
        time: "18:00",
        localTimezone: LOS_ANGELES,
      },
      {
        previews: [
          {
            current: true,
            formated:
              'Wednesday, May 13, 2020 <br /><svg class=\'fa d-icon d-icon-clock svg-icon svg-string\' xmlns="http://www.w3.org/2000/svg"><use href="#clock" /></svg> 11:00 AM',
            timezone: "Los Angeles",
          },
          {
            formated:
              'Wednesday, May 13, 2020 <br /><svg class=\'fa d-icon d-icon-clock svg-icon svg-string\' xmlns="http://www.w3.org/2000/svg"><use href="#clock" /></svg> 6:00 PM',
            timezone: "UTC",
          },
        ],
      }
    );
  });
});

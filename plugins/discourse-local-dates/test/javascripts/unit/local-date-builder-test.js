import QUnit, { module, test } from "qunit";
import { i18n } from "discourse-i18n";
import freezeTime from "../helpers/freeze-time";
import LocalDateBuilder from "../lib/local-date-builder";

const UTC = "Etc/UTC";
const SYDNEY = "Australia/Sydney";
const LOS_ANGELES = "America/Los_Angeles";
const NEW_YORK = "America/New_York";
const PARIS = "Europe/Paris";
const LAGOS = "Africa/Lagos";
const LONDON = "Europe/London";
const SINGAPORE = "Asia/Singapore";

QUnit.assert.buildsCorrectDate = function (options, expected, message) {
  const localTimezone = options.localTimezone || PARIS;
  delete options.localTimezone;

  const localDateBuilder = new LocalDateBuilder(
    Object.assign(
      {},
      {
        date: "2022-03-20",
      },
      options
    ),
    localTimezone
  );

  if (expected.formatted) {
    this.test.assert.strictEqual(
      localDateBuilder.build().formatted,
      expected.formatted,
      message || "it formats the date correctly"
    );
  }

  if (expected.previews) {
    this.test.assert.deepEqual(
      localDateBuilder.build().previews,
      expected.previews,
      message || "it formats the previews correctly"
    );
  }
};

module("Unit | Library | local-date-builder", function () {
  test("date", function (assert) {
    freezeTime({ date: "2022-03-11" }, () => {
      assert.buildsCorrectDate(
        { date: "2022-03-20", timezone: PARIS },
        { formatted: "March 20, 2022" },
        "it displays the date without time"
      );
    });

    freezeTime({ date: "2022-10-11", timezone: "Asia/Singapore" }, () => {
      const localDateBuilder = new LocalDateBuilder(
        {
          date: "2022-10-12",
          timezone: SINGAPORE,
          localTimezone: SINGAPORE,
        },
        SINGAPORE
      );

      assert.strictEqual(
        localDateBuilder.build().formatted,
        "Tomorrow",
        "Displays relative day"
      );
    });
  });

  test("date and time", function (assert) {
    assert.buildsCorrectDate(
      { date: "2022-04-11", time: "11:00" },
      { formatted: "April 11, 2022 1:00 PM" },
      "it displays the date with time"
    );

    assert.buildsCorrectDate(
      { date: "2022-04-11", time: "11:05:12", format: "LTS" },
      { formatted: "1:05:12 PM" },
      "it displays full time (hours, minutes, seconds)"
    );
  });

  test("time", function (assert) {
    assert.buildsCorrectDate(
      {
        time: "12:22:00",
        date: "2022-10-07",
        timezone: SINGAPORE,
        localTimezone: SINGAPORE,
        sameLocalDayAsFrom: true,
      },
      { formatted: "12:22 PM (Singapore)" },
      "it displays the time only as the date is the same local day as 'from'"
    );
  });

  test("option[format]", function (assert) {
    freezeTime({ date: "2022-03-11" }, () => {
      assert.buildsCorrectDate(
        { format: "YYYY" },
        { formatted: "2022 (UTC)" },
        "it uses custom format"
      );
    });
  });

  test("option[displayedTimezone]", function (assert) {
    freezeTime({}, () => {
      assert.buildsCorrectDate(
        { displayedTimezone: SYDNEY },
        { formatted: "March 20, 2022 (Sydney)" },
        "it displays the timezone if the timezone is different from the date"
      );
    });

    freezeTime({}, () => {
      assert.buildsCorrectDate(
        { displayedTimezone: PARIS, timezone: PARIS },
        { formatted: "March 20, 2022" },
        "it doesn't display the timezone if the timezone is the same than the date"
      );
    });

    freezeTime({}, () => {
      assert.buildsCorrectDate(
        { timezone: UTC, displayedTimezone: UTC },
        { formatted: "March 20, 2022 (UTC)" },
        "it replaces `Etc/`"
      );
    });

    freezeTime({}, () => {
      assert.buildsCorrectDate(
        { timezone: LOS_ANGELES, displayedTimezone: LOS_ANGELES },
        { formatted: "March 20, 2022 (Los Angeles)" },
        "it removes prefix and replaces `_`"
      );
    });
  });

  test("option[timezone]", function (assert) {
    freezeTime({}, () => {
      assert.buildsCorrectDate(
        { timezone: SYDNEY, displayedTimezone: PARIS },
        { formatted: "March 19, 2022" },
        "it correctly parses a date with the given timezone context"
      );
    });
  });

  test("option[recurring]", function (assert) {
    freezeTime({ date: "2022-04-04 06:00", timezone: LAGOS }, () => {
      assert.buildsCorrectDate(
        {
          date: "2021-11-22",
          time: "11:00",
          timezone: PARIS,
          displayedTimezone: LAGOS,
          recurring: "1.weeks",
        },
        {
          formatted: "April 4, 2022 10:00 AM (Lagos)",
        },
        "it correctly formats a recurring date starting from a !isDST timezone to a isDST timezone date when displayed to a user using a timezone with no DST"
      );
    });

    freezeTime({ date: "2022-04-04 01:00", timezone: SYDNEY }, () => {
      assert.buildsCorrectDate(
        {
          date: "2022-03-07",
          time: "02:00",
          timezone: UTC,
          recurring: "1.weeks",
          calendar: false,
          displayedTimezone: SYDNEY,
        },
        {
          formatted: "April 4, 2022 12:00 PM (Sydney)",
        },
        "it correctly formats a recurring date spanning over weeks"
      );
    });

    freezeTime({ date: "2022-04-05 22:00" }, () => {
      assert.buildsCorrectDate(
        {
          date: "2021-11-22",
          time: "11:00",
          recurring: "1.weeks",
          timezone: PARIS,
        },
        {
          formatted: "April 11, 2022 11:00 AM",
        },
        "it correctly adds from a !isDST date to a isDST date"
      );
    });

    freezeTime({ date: "2022-04-04 10:59" }, () => {
      assert.buildsCorrectDate(
        {
          date: "2022-03-28",
          time: "11:00",
          recurring: "1.weeks",
          timezone: PARIS,
        },
        {
          formatted: "Today 11:00 AM",
        },
        "it works to the minute"
      );
    });

    freezeTime({ date: "2022-04-04 11:01" }, () => {
      assert.buildsCorrectDate(
        {
          date: "2022-03-28",
          time: "11:00",
          recurring: "1.weeks",
          timezone: PARIS,
        },
        {
          formatted: "April 11, 2022 11:00 AM",
        },
        "it works to the minute"
      );
    });

    freezeTime({ date: "2022-12-26 09:16" }, () => {
      assert.buildsCorrectDate(
        {
          date: "2023-01-22",
          time: "08:30",
          recurring: "1.weeks",
          timezone: NEW_YORK,
        },
        {
          formatted: "January 22, 2023 2:30 PM",
        },
        "it works for a future date"
      );
    });

    freezeTime({ date: "2023-01-06 11:16" }, () => {
      assert.buildsCorrectDate(
        {
          date: "2023-01-03",
          time: "14:00",
          recurring: "2.hours",
          timezone: NEW_YORK,
        },
        {
          formatted: "Today 12:00 PM",
        },
        "it works with hours"
      );
    });
  });

  test("option[countdown]", function (assert) {
    freezeTime({ date: "2022-03-19 23:59" }, () => {
      assert.buildsCorrectDate(
        {
          countdown: true,
          timezone: PARIS,
        },
        { formatted: "a minute" },
        "it shows the time remaining"
      );
    });

    freezeTime({ date: "2022-03-20 00:01" }, () => {
      assert.buildsCorrectDate(
        {
          countdown: true,
          timezone: PARIS,
        },
        {
          formatted: i18n(
            "discourse_local_dates.relative_dates.countdown.passed"
          ),
        },
        "it shows the date has passed"
      );
    });
  });

  test("option[calendar]", function (assert) {
    freezeTime({ date: "2022-03-21 23:00" }, () => {
      assert.buildsCorrectDate(
        { date: "2022-03-20", time: "23:59", timezone: PARIS },
        { formatted: "Yesterday 11:59 PM" },
        "it drops calendar mode when event date is more than one day before current date"
      );
    });

    freezeTime({ date: "2022-03-18 23:59" }, () =>
      assert.buildsCorrectDate(
        { date: "2022-03-19", time: "01:00", timezone: PARIS },
        { formatted: "Tomorrow 1:00 AM" }
      )
    );

    freezeTime({ date: "2022-03-18 23:59" }, () =>
      assert.buildsCorrectDate(
        { date: "2022-03-19", time: "00:00", timezone: PARIS },
        { formatted: "Saturday" },
        "it displays the day with no time when the time in the displayed timezone is 00:00"
      )
    );

    freezeTime({ date: "2022-03-18 23:59" }, () => {
      assert.buildsCorrectDate(
        { date: "2022-03-19", time: "23:59", timezone: PARIS },
        { formatted: "Tomorrow 11:59 PM" }
      );
    });

    freezeTime({ date: "2022-03-19 00:00" }, () =>
      assert.buildsCorrectDate(
        { date: "2022-03-19", time: "23:00", timezone: PARIS },
        { formatted: "Today 11:00 PM" }
      )
    );

    freezeTime({ date: "2022-03-20 23:59" }, () =>
      assert.buildsCorrectDate(
        { date: "2022-03-19", time: "23:59", timezone: PARIS },
        { formatted: "Yesterday 11:59 PM" }
      )
    );

    freezeTime({ date: "2022-03-20 23:59" }, () =>
      assert.buildsCorrectDate(
        { date: "2022-03-19", time: "23:59", timezone: PARIS },
        { formatted: "Yesterday 11:59 PM" }
      )
    );

    freezeTime({ date: "2022-03-20 23:59" }, () =>
      assert.buildsCorrectDate(
        { calendar: false, date: "2022-03-19", time: "23:59", timezone: PARIS },
        { formatted: "March 19, 2022 11:59 PM" },
        "it doesn't use calendar when disabled"
      )
    );

    freezeTime({ date: "2022-03-22 01:00" }, () =>
      assert.buildsCorrectDate(
        { date: "2022-03-19", timezone: PARIS },
        { formatted: "March 19, 2022" },
        "it stops formatting out of calendar range"
      )
    );

    freezeTime({ date: "2022-05-10", timezone: LOS_ANGELES }, () => {
      assert.buildsCorrectDate(
        {
          date: "2022-05-11",
          time: "18:00",
          localTimezone: LOS_ANGELES,
        },
        { formatted: "Tomorrow 11:00 AM" },
        "it correctly displays a different local timezone"
      );
    });
  });

  test("previews", function (assert) {
    freezeTime({ date: "2022-03-20" }, () => {
      assert.buildsCorrectDate(
        { timezone: PARIS },
        {
          previews: [
            {
              current: true,
              formatted:
                "Sunday, March 20, 2022 12:00 AM → Monday, March 21, 2022 12:00 AM",
              timezone: "Paris",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-03-20", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        { timezone: PARIS, timezones: [SYDNEY] },
        {
          previews: [
            {
              current: true,
              formatted:
                "Sunday, March 20, 2022 12:00 AM → Monday, March 21, 2022 12:00 AM",
              timezone: "Paris",
            },
            {
              formatted:
                "Sunday, March 20, 2022 10:00 AM → Monday, March 21, 2022 10:00 AM",
              timezone: "Sydney",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-03-20", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        { timezone: PARIS, displayedTimezone: LOS_ANGELES },
        {
          previews: [
            {
              current: true,
              formatted:
                "Sunday, March 20, 2022 12:00 AM → Monday, March 21, 2022 12:00 AM",
              timezone: "Paris",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-03-20", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        { timezone: PARIS, displayedTimezone: PARIS },
        {
          previews: [
            {
              current: true,
              formatted:
                "Sunday, March 20, 2022 12:00 AM → Monday, March 21, 2022 12:00 AM",
              timezone: "Paris",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-03-20", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        { timezone: PARIS, timezones: [PARIS] },
        {
          previews: [
            {
              current: true,
              formatted:
                "Sunday, March 20, 2022 12:00 AM → Monday, March 21, 2022 12:00 AM",
              timezone: "Paris",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-03-20", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        { duration: 90, timezone: PARIS, timezones: [PARIS] },
        {
          previews: [
            {
              current: true,
              formatted:
                "Sunday, March 20, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon fa-width-auto svg-string' width='1em' height='1em' aria-hidden='true' xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#clock\" /></svg> 12:00 AM → 1:30 AM",
              timezone: "Paris",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-03-20", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        { duration: 1440, timezone: PARIS, timezones: [PARIS] },
        {
          previews: [
            {
              current: true,
              formatted:
                "Sunday, March 20, 2022 12:00 AM → Monday, March 21, 2022 12:00 AM",
              timezone: "Paris",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-03-20", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        { time: "11:34", timezone: PARIS, timezones: [PARIS] },
        {
          previews: [
            {
              current: true,
              formatted:
                "Sunday, March 20, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon fa-width-auto svg-string' width='1em' height='1em' aria-hidden='true' xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#clock\" /></svg> 11:34 AM",
              timezone: "Paris",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-04-04", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        {
          timezone: PARIS,
          date: "2022-04-05",
          timezones: [LONDON, LAGOS, SYDNEY],
        },
        {
          previews: [
            {
              current: true,
              formatted:
                "Tuesday, April 5, 2022 12:00 AM → Wednesday, April 6, 2022 12:00 AM",
              timezone: "Paris",
            },
            {
              formatted:
                "Monday, April 4, 2022 11:00 PM → Tuesday, April 5, 2022 11:00 PM",
              timezone: "London",
            },
            {
              formatted:
                "Monday, April 4, 2022 11:00 PM → Tuesday, April 5, 2022 11:00 PM",
              timezone: "Lagos",
            },
            {
              formatted:
                "Tuesday, April 5, 2022 8:00 AM → Wednesday, April 6, 2022 8:00 AM",
              timezone: "Sydney",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-04-04", timezone: PARIS }, () => {
      assert.buildsCorrectDate(
        {
          timezone: PARIS,
          date: "2022-04-05",
          time: "14:54",
          timezones: [LONDON, LAGOS, SYDNEY],
        },
        {
          previews: [
            {
              current: true,
              formatted:
                "Tuesday, April 5, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon fa-width-auto svg-string' width='1em' height='1em' aria-hidden='true' xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#clock\" /></svg> 2:54 PM",
              timezone: "Paris",
            },
            {
              formatted:
                "Tuesday, April 5, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon fa-width-auto svg-string' width='1em' height='1em' aria-hidden='true' xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#clock\" /></svg> 1:54 PM",
              timezone: "London",
            },
            {
              formatted:
                "Tuesday, April 5, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon fa-width-auto svg-string' width='1em' height='1em' aria-hidden='true' xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#clock\" /></svg> 1:54 PM",
              timezone: "Lagos",
            },
            {
              formatted:
                "Tuesday, April 5, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon fa-width-auto svg-string' width='1em' height='1em' aria-hidden='true' xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#clock\" /></svg> 10:54 PM",
              timezone: "Sydney",
            },
          ],
        }
      );
    });

    freezeTime({ date: "2022-05-10", timezone: LOS_ANGELES }, () => {
      assert.buildsCorrectDate(
        {
          date: "2022-05-11",
          time: "18:00",
          localTimezone: LOS_ANGELES,
        },
        {
          previews: [
            {
              current: true,
              formatted:
                "Wednesday, May 11, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon fa-width-auto svg-string' width='1em' height='1em' aria-hidden='true' xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#clock\" /></svg> 11:00 AM",
              timezone: "Los Angeles",
            },
            {
              formatted:
                "Wednesday, May 11, 2022 <br /><svg class='fa d-icon d-icon-clock svg-icon fa-width-auto svg-string' width='1em' height='1em' aria-hidden='true' xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#clock\" /></svg> 6:00 PM",
              timezone: "UTC",
            },
          ],
        }
      );
    });
  });
});

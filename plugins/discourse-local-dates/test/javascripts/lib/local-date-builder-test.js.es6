import LocalDateBuilder from "./local-date-builder";

const UTC = "Etc/UTC";
const SYDNEY = "Australia/Sydney";
const LOS_ANGELES = "America/Los_Angeles";
const PARIS = "Europe/Paris";
const LAGOS = "Africa/Lagos";
const LONDON = "Europe/London";

QUnit.module("lib:local-date-builder");

const sandbox = sinon.createSandbox();

function freezeTime({ date, timezone }, cb) {
  date = date || "2020-01-22 10:34";
  const newTimezone = timezone || PARIS;
  const previousZone = moment.tz.guess();
  const now = moment.tz(date, newTimezone).valueOf();

  sandbox.useFakeTimers(now);
  sandbox.stub(moment.tz, "guess");
  moment.tz.guess.returns(newTimezone);
  moment.tz.setDefault(newTimezone);

  cb();

  moment.tz.guess.returns(previousZone);
  moment.tz.setDefault(previousZone);
  sandbox.restore();
}

QUnit.assert.buildsCorrectDate = function(options, expected, message) {
  const localTimezone = options.localTimezone || PARIS;
  delete options.localTimezone;

  const localDateBuilder = new LocalDateBuilder(
    Object.assign(
      {},
      {
        date: "2020-03-22"
      },
      options
    ),
    localTimezone
  );

  if (expected.formated) {
    this.test.assert.equal(
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

QUnit.test("date", assert => {
  freezeTime({ date: "2020-03-11" }, () => {
    assert.buildsCorrectDate(
      {},
      { formated: "March 22, 2020" },
      "it displays the date without time"
    );

    assert.buildsCorrectDate(
      { date: "2020-04-11", time: "11:00" },
      { formated: "April 11, 2020 11:00 AM" },
      "it displays the date with time"
    );
  });
});

QUnit.test("option[format]", assert => {
  freezeTime({ date: "2020-03-11" }, () => {
    assert.buildsCorrectDate(
      { format: "YYYY" },
      { formated: "2020" },
      "it uses custom format"
    );
  });
});

QUnit.test("option[displayedTimezone]", assert => {
  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { displayedTimezone: SYDNEY },
      { formated: "March 22, 2020 (Sydney)" },
      "it displays the timezone if the timezone is different from the date"
    );
  });

  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { displayedTimezone: PARIS },
      { formated: "March 22, 2020" },
      "it doesn't display the timezone if the timezone is the same than the date"
    );
  });
});

QUnit.test("options[timezone]", assert => {
  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { timezone: "Etc/UTC" },
      { formated: "March 21, 2020 (UTC)" },
      "it replaces `Etc/`"
    );
  });
  freezeTime({}, () => {
    assert.buildsCorrectDate(
      { timezone: LOS_ANGELES },
      { formated: "March 21, 2020 (Los Angeles)" },
      "it removes prefix and replaces `_`"
    );
  });
});

QUnit.test("option[recurring]", assert => {
  freezeTime({ date: "2020-04-06 06:00", timezone: LAGOS }, () => {
    assert.buildsCorrectDate(
      {
        date: "2019-11-25",
        time: "11:00",
        timezone: PARIS,
        displayedTimezone: LAGOS,
        recurring: "1.weeks"
      },
      {
        formated: "April 6, 2020 10:00 AM (Lagos)"
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
        displayedTimezone: SYDNEY
      },
      {
        formated: "April 6, 2020 10:00 AM (Sydney)"
      },
      "it correctly formats a recurring date spanning over weeks"
    );
  });

  freezeTime({ date: "2020-04-07 22:00" }, () => {
    assert.buildsCorrectDate(
      {
        date: "2019-11-25",
        time: "11:00",
        recurring: "1.weeks"
      },
      {
        formated: "April 13, 2020 11:00 AM"
      },
      "it correctly adds from a !isDST date to a isDST date"
    );
  });

  freezeTime({ date: "2020-04-06 10:59" }, () => {
    assert.buildsCorrectDate(
      {
        date: "2020-03-30",
        time: "11:00",
        recurring: "1.weeks"
      },
      {
        formated: "Today 11:00 AM"
      },
      "it works to the minute"
    );
  });

  freezeTime({ date: "2020-04-06 11:01" }, () => {
    assert.buildsCorrectDate(
      {
        date: "2020-03-30",
        time: "11:00",
        recurring: "1.weeks"
      },
      {
        formated: "April 13, 2020 11:00 AM"
      },
      "it works to the minute"
    );
  });
});

QUnit.test("option[countown]", assert => {
  freezeTime({ date: "2020-03-21 23:59" }, () => {
    assert.buildsCorrectDate(
      {
        countdown: true
      },
      { formated: "a minute" },
      "it shows the time remaining"
    );
  });

  freezeTime({ date: "2020-03-22 00:01" }, () => {
    assert.buildsCorrectDate(
      {
        countdown: true
      },
      {
        formated: I18n.t(
          "discourse_local_dates.relative_dates.countdown.passed"
        )
      },
      "it shows the date has passed"
    );
  });
});

QUnit.test("option[calendar]", assert => {
  freezeTime({ date: "2020-03-23 23:00", timezone: "Etc/UTC" }, () =>
    assert.buildsCorrectDate(
      {},
      { formated: "March 22, 2020" },
      "it drops calendar mode when event date is more than one day before current date"
    )
  );

  freezeTime({ date: "2020-03-20 23:59", timezone: "Etc/UTC" }, () =>
    assert.buildsCorrectDate({}, { formated: "Tomorrow" })
  );

  freezeTime({ date: "2020-03-21 22:59", timezone: "Etc/UTC" }, () =>
    assert.buildsCorrectDate({}, { formated: "Tomorrow" })
  );

  freezeTime({ date: "2020-03-21 23:00", timezone: "Etc/UTC" }, () =>
    assert.buildsCorrectDate({}, { formated: "Today" })
  );

  freezeTime({ date: "2020-03-22 22:59", timezone: "Etc/UTC" }, () =>
    assert.buildsCorrectDate({}, { formated: "Today" })
  );

  freezeTime({ date: "2020-03-22 23:00", timezone: "Etc/UTC" }, () =>
    assert.buildsCorrectDate({}, { formated: "Yesterday" })
  );

  freezeTime({ date: "2020-03-23 22:59", timezone: "Etc/UTC" }, () =>
    assert.buildsCorrectDate({}, { formated: "Yesterday" })
  );

  freezeTime({ date: "2020-03-24 01:00", timezone: "Etc/UTC" }, () =>
    assert.buildsCorrectDate({}, { formated: "March 22, 2020" })
  );
});

QUnit.test("previews", assert => {
  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      {},
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Europe/Paris"
          }
        ]
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { timezones: [SYDNEY] },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Europe/Paris"
          },
          {
            formated:
              "Sunday, March 22, 2020 10:00 AM → Monday, March 23, 2020 10:00 AM",
            timezone: "Australia/Sydney"
          }
        ]
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { displayedTimezone: LOS_ANGELES },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Europe/Paris"
          }
        ]
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { displayedTimezone: PARIS },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Europe/Paris"
          }
        ]
      }
    );
  });

  freezeTime({ date: "2020-03-22", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { timezones: [PARIS] },
      {
        previews: [
          {
            current: true,
            formated:
              "Sunday, March 22, 2020 12:00 AM → Monday, March 23, 2020 12:00 AM",
            timezone: "Europe/Paris"
          }
        ]
      }
    );
  });

  freezeTime({ date: "2020-04-06", timezone: PARIS }, () => {
    assert.buildsCorrectDate(
      { date: "2020-04-07", timezones: [LONDON, LAGOS] },
      {
        previews: [
          {
            current: true,
            formated:
              "Tuesday, April 7, 2020 12:00 AM → Wednesday, April 8, 2020 12:00 AM",
            timezone: "Europe/Paris"
          },
          {
            formated:
              "Monday, April 6, 2020 11:00 PM → Tuesday, April 7, 2020 11:00 PM",
            timezone: "Europe/London"
          },
          {
            formated:
              "Monday, April 6, 2020 11:00 PM → Tuesday, April 7, 2020 11:00 PM",
            timezone: "Africa/Lagos"
          }
        ]
      }
    );
  });
});

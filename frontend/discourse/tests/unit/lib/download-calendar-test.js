import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  downloadGoogle,
  downloadOutlook,
  formatDates,
  generateIcsData,
} from "discourse/lib/download-calendar";

module("Unit | Utility | download-calendar", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    let win = { focus: function () {} };
    sinon.stub(window, "open").returns(win);
    sinon.stub(win, "focus");
  });

  test("correct data for ICS with timezone", function (assert) {
    const now = moment.tz("2022-04-04 23:15", "Europe/Paris").valueOf();
    sinon.useFakeTimers({
      now,
      toFake: ["Date"],
      shouldAdvanceTime: true,
      shouldClearNativeTimers: true,
    });
    const data = generateIcsData(
      "event test",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
          timezone: "Europe/Paris",
        },
      ],
      {
        rrule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",
        location: "Paris",
        details: "Good soup",
      }
    );

    assert.true(data.includes("BEGIN:VCALENDAR"));
    assert.true(data.includes("DTSTART;TZID=Europe/Paris:20211012T170000"));
    assert.true(data.includes("DTEND;TZID=Europe/Paris:20211012T180000"));
    assert.true(data.includes("RRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR"));
    assert.true(data.includes("LOCATION:Paris"));
    assert.true(data.includes("DESCRIPTION:Good soup"));
    assert.true(data.includes("SUMMARY:event test"));
    assert.true(data.includes("END:VEVENT"));
    assert.true(data.includes("END:VCALENDAR"));
  });

  test("timezone ICS includes a VTIMEZONE definition", function (assert) {
    const data = generateIcsData("testevent 2", [
      {
        startsAt: "2026-08-11T15:00:00.000Z",
        endsAt: "2026-08-11T17:15:00.000Z",
        timezone: "Europe/Berlin",
      },
    ]);

    assert.true(
      data.includes(
        [
          "BEGIN:VTIMEZONE",
          "TZID:Europe/Berlin",
          "BEGIN:DAYLIGHT",
          "DTSTART:20260329T020000",
          "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU",
          "TZOFFSETFROM:+0100",
          "TZOFFSETTO:+0200",
          "TZNAME:CEST",
          "END:DAYLIGHT",
        ].join("\r\n")
      ),
      "includes the Berlin daylight-saving observance"
    );
    assert.true(
      data.includes(
        [
          "BEGIN:STANDARD",
          "DTSTART:20261025T030000",
          "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU",
          "TZOFFSETFROM:+0200",
          "TZOFFSETTO:+0100",
          "TZNAME:CET",
          "END:STANDARD",
          "END:VTIMEZONE",
        ].join("\r\n")
      ),
      "includes the Berlin standard-time observance"
    );
    assert.true(data.includes("DTSTART;TZID=Europe/Berlin:20260811T170000"));
    assert.true(data.includes("DTEND;TZID=Europe/Berlin:20260811T191500"));
  });

  test("VTIMEZONE supports North American DST rules", function (assert) {
    const data = generateIcsData("New York event", [
      {
        startsAt: "2026-07-15T16:00:00.000Z",
        endsAt: "2026-07-15T17:00:00.000Z",
        timezone: "America/New_York",
      },
    ]);

    assert.true(
      data.includes(
        [
          "BEGIN:DAYLIGHT",
          "DTSTART:20260308T020000",
          "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU",
          "TZOFFSETFROM:-0500",
          "TZOFFSETTO:-0400",
          "TZNAME:EDT",
          "END:DAYLIGHT",
        ].join("\r\n")
      ),
      "includes the New York daylight-saving observance"
    );
    assert.true(
      data.includes(
        [
          "BEGIN:STANDARD",
          "DTSTART:20261101T020000",
          "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU",
          "TZOFFSETFROM:-0400",
          "TZOFFSETTO:-0500",
          "TZNAME:EST",
          "END:STANDARD",
        ].join("\r\n")
      ),
      "includes the New York standard-time observance"
    );
    assert.true(data.includes("DTSTART;TZID=America/New_York:20260715T120000"));
  });

  test("VTIMEZONE supports zones with a stable current offset", function (assert) {
    const data = generateIcsData("Kolkata event", [
      {
        startsAt: "2026-08-11T12:00:00.000Z",
        endsAt: "2026-08-11T13:00:00.000Z",
        timezone: "Asia/Kolkata",
      },
    ]);

    assert.true(data.includes("BEGIN:VTIMEZONE"));
    assert.true(data.includes("TZID:Asia/Kolkata"));
    assert.true(data.includes("BEGIN:STANDARD"));
    assert.true(data.includes("TZOFFSETTO:+0530"));
    assert.true(data.includes("TZNAME:IST"));
    assert.false(data.includes("BEGIN:DAYLIGHT"));
    assert.true(data.includes("DTSTART;TZID=Asia/Kolkata:20260811T173000"));
  });

  test("VTIMEZONE supports a zero standard UTC offset", function (assert) {
    const data = generateIcsData("London event", [
      {
        startsAt: "2026-08-11T12:00:00.000Z",
        endsAt: "2026-08-11T13:00:00.000Z",
        timezone: "Europe/London",
      },
    ]);

    assert.true(
      data.includes(
        [
          "BEGIN:DAYLIGHT",
          "DTSTART:20260329T010000",
          "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU",
          "TZOFFSETFROM:+0000",
          "TZOFFSETTO:+0100",
          "TZNAME:BST",
          "END:DAYLIGHT",
        ].join("\r\n")
      ),
      "includes the London daylight-saving observance"
    );
    assert.true(
      data.includes(
        [
          "BEGIN:STANDARD",
          "DTSTART:20261025T020000",
          "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU",
          "TZOFFSETFROM:+0100",
          "TZOFFSETTO:+0000",
          "TZNAME:GMT",
          "END:STANDARD",
        ].join("\r\n")
      ),
      "includes the London standard-time observance"
    );
    assert.true(data.includes("DTSTART;TZID=Europe/London:20260811T130000"));
  });

  test("VTIMEZONE falls back to a fixed offset for irregular seasonal zones", function (assert) {
    // Morocco's transitions follow Ramadan, so the calendar rule differs every
    // year. There is no stable RRULE to emit; the current offset is used instead.
    const data = generateIcsData("Casablanca event", [
      {
        startsAt: "2025-08-11T12:00:00.000Z",
        endsAt: "2025-08-11T13:00:00.000Z",
        timezone: "Africa/Casablanca",
      },
    ]);

    assert.true(data.includes("TZID:Africa/Casablanca"));
    assert.strictEqual(
      data.match(/BEGIN:STANDARD/g).length,
      1,
      "emits exactly one STANDARD observance"
    );
    assert.false(data.includes("BEGIN:DAYLIGHT"), "no DAYLIGHT observance");
    assert.false(
      /^RRULE:/m.test(data.split("BEGIN:VEVENT")[0]),
      "no recurrence rule inside the VTIMEZONE"
    );
    assert.true(data.includes("TZOFFSETFROM:+0100"));
    assert.true(data.includes("TZOFFSETTO:+0100"));
    assert.true(
      data.includes("DTSTART;TZID=Africa/Casablanca:20250811T130000"),
      "event local time still uses the named timezone"
    );
  });

  test("correct data for ICS without timezone (UTC)", function (assert) {
    const now = moment.tz("2022-04-04 23:15", "Europe/Paris").valueOf();
    sinon.useFakeTimers({
      now,
      toFake: ["Date"],
      shouldAdvanceTime: true,
      shouldClearNativeTimers: true,
    });
    const data = generateIcsData(
      "event test",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
        },
      ],
      {
        rrule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",
        location: "Paris",
        details: "Good soup",
      }
    );

    assert.strictEqual(
      data,
      `BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Discourse//EN\r\nBEGIN:VEVENT\r\nUID:1634050800000_1634054400000\r\nDTSTAMP:20220404T211500Z\r\nDTSTART:20211012T150000Z\r\nDTEND:20211012T160000Z\r\nRRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR\r\nLOCATION:Paris\r\nDESCRIPTION:Good soup\r\nSUMMARY:event test\r\nEND:VEVENT\r\nEND:VCALENDAR`
    );
  });

  test("correct data for ICS when recurring event with timezone", function (assert) {
    const now = moment.tz("2022-04-04 23:15", "Europe/Paris").valueOf();
    sinon.useFakeTimers({
      now,
      toFake: ["Date"],
      shouldAdvanceTime: true,
      shouldClearNativeTimers: true,
    });
    const data = generateIcsData(
      "event test",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
          timezone: "America/New_York",
        },
      ],
      { rrule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR" }
    );

    assert.true(data.includes("DTSTART;TZID=America/New_York:20211012T110000"));
    assert.true(data.includes("DTEND;TZID=America/New_York:20211012T120000"));
    assert.true(data.includes("RRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR"));

    sinon.restore();
  });

  test("correct data for ICS when recurring event without timezone", function (assert) {
    const now = moment.tz("2022-04-04 23:15", "Europe/Paris").valueOf();
    sinon.useFakeTimers({
      now,
      toFake: ["Date"],
      shouldAdvanceTime: true,
      shouldClearNativeTimers: true,
    });
    const data = generateIcsData(
      "event test",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
        },
      ],
      { rrule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR" }
    );
    assert.strictEqual(
      data,
      `BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Discourse//EN\r\nBEGIN:VEVENT\r\nUID:1634050800000_1634054400000\r\nDTSTAMP:20220404T211500Z\r\nDTSTART:20211012T150000Z\r\nDTEND:20211012T160000Z\r\nRRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR\r\nSUMMARY:event test\r\nEND:VEVENT\r\nEND:VCALENDAR`
    );

    sinon.restore();
  });

  test("correct url for Google", function (assert) {
    downloadGoogle("event", [
      {
        startsAt: "2021-10-12T15:00:00.000Z",
        endsAt: "2021-10-12T16:00:00.000Z",
      },
    ]);
    assert.true(
      window.open.calledWith(
        "https://www.google.com/calendar/event?action=TEMPLATE&text=event&dates=20211012T150000Z%2F20211012T160000Z",
        "_blank",
        "noopener",
        "noreferrer"
      )
    );
  });

  test("correct url for Google with timezone", function (assert) {
    // America/New_York is UTC-4 in October, so 18:30 NY = 22:30 UTC
    downloadGoogle("event", [
      {
        startsAt: "2021-10-12T18:30:00",
        endsAt: "2021-10-12T21:00:00",
        timezone: "America/New_York",
      },
    ]);
    assert.true(
      window.open.calledWith(
        "https://www.google.com/calendar/event?action=TEMPLATE&text=event&dates=20211012T223000Z%2F20211013T010000Z",
        "_blank",
        "noopener",
        "noreferrer"
      )
    );
  });

  test("correct url for Google when recurring event", function (assert) {
    downloadGoogle(
      "event",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
        },
      ],
      { rrule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR" }
    );
    assert.true(
      window.open.calledWith(
        "https://www.google.com/calendar/event?action=TEMPLATE&text=event&dates=20211012T150000Z%2F20211012T160000Z&recur=RRULE%3AFREQ%3DDAILY%3BBYDAY%3DMO%2CTU%2CWE%2CTH%2CFR",
        "_blank",
        "noopener",
        "noreferrer"
      )
    );
  });

  test("correct url for Google when recurring event with DTSTART prefix", function (assert) {
    downloadGoogle(
      "event",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
        },
      ],
      {
        rrule:
          "DTSTART:20211012T150000Z\nRRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",
      }
    );
    assert.true(
      window.open.calledWith(
        "https://www.google.com/calendar/event?action=TEMPLATE&text=event&dates=20211012T150000Z%2F20211012T160000Z&recur=RRULE%3AFREQ%3DDAILY%3BBYDAY%3DMO%2CTU%2CWE%2CTH%2CFR",
        "_blank",
        "noopener",
        "noreferrer"
      )
    );
  });

  test("correct location for Google when location given", function (assert) {
    downloadGoogle(
      "event",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
        },
      ],
      { location: "Paris" }
    );
    assert.true(
      window.open.calledWith(
        "https://www.google.com/calendar/event?action=TEMPLATE&text=event&dates=20211012T150000Z%2F20211012T160000Z&location=Paris",
        "_blank",
        "noopener",
        "noreferrer"
      )
    );
  });

  test("correct details for Google when details given", function (assert) {
    downloadGoogle(
      "event",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
        },
      ],
      { details: "Cool" }
    );
    assert.true(
      window.open.calledWith(
        "https://www.google.com/calendar/event?action=TEMPLATE&text=event&dates=20211012T150000Z%2F20211012T160000Z&details=Cool",
        "_blank",
        "noopener",
        "noreferrer"
      )
    );
  });

  test("correct url for Outlook", function (assert) {
    downloadOutlook(
      "event & lunch",
      [
        {
          startsAt: "2021-10-12T18:30:00",
          endsAt: "2021-10-12T21:00:00",
          timezone: "America/New_York",
        },
      ],
      { details: "Cool", location: "New York" }
    );

    const [url, target, ...features] = window.open.getCall(0).args;
    const link = new URL(url);

    assert.strictEqual(
      link.origin + link.pathname,
      "https://outlook.live.com/calendar/0/deeplink/compose"
    );
    assert.deepEqual(Object.fromEntries(link.searchParams), {
      path: "/calendar/action/compose",
      rru: "addevent",
      subject: "event & lunch",
      startdt: "2021-10-12T22:30:00.000Z",
      enddt: "2021-10-13T01:00:00.000Z",
      allday: "false",
      location: "New York",
      body: "Cool",
    });
    assert.strictEqual(target, "_blank");
    assert.deepEqual(features, ["noopener", "noreferrer"]);
  });

  test("all-day Outlook url uses an exclusive date-only range", function (assert) {
    downloadOutlook("all day event", [
      { startsAt: "2026-03-12", endsAt: "2026-03-14", allDay: true },
    ]);

    const link = new URL(window.open.getCall(0).args[0]);

    assert.strictEqual(link.searchParams.get("startdt"), "2026-03-12");
    assert.strictEqual(link.searchParams.get("enddt"), "2026-03-15");
    assert.strictEqual(link.searchParams.get("allday"), "true");
  });

  test("recurring Outlook events fall back to ICS", function (assert) {
    sinon.stub(URL, "createObjectURL").returns("blob:calendar");
    sinon.stub(HTMLAnchorElement.prototype, "click");

    downloadOutlook(
      "event",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
        },
      ],
      { rrule: "FREQ=WEEKLY;BYDAY=TU" }
    );

    assert.true(HTMLAnchorElement.prototype.click.calledOnce);
    assert.false(window.open.called);
  });

  test("calculates end date when none given", function (assert) {
    let dates = formatDates([{ startsAt: "2021-10-12T15:00:00.000Z" }]);
    assert.deepEqual(
      dates,
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00Z",
        },
      ],
      "endsAt is one hour after startsAt"
    );
  });

  test("all-day ICS uses DATE values with an exclusive end date", function (assert) {
    const data = generateIcsData("all day event", [
      { startsAt: "2026-03-12", endsAt: "2026-03-14", allDay: true },
    ]);

    assert.true(
      data.includes("DTSTART;VALUE=DATE:20260312"),
      "start is a DATE value"
    );
    assert.true(
      data.includes("DTEND;VALUE=DATE:20260315"),
      "end is the exclusive day after the last day"
    );
    assert.false(
      data.includes("DTSTART:20260312T000000Z"),
      "does not emit a midnight datetime"
    );
    assert.false(data.includes("TZID"), "does not emit a timezone");
  });

  test("single-day all-day ICS spans one day when no end given", function (assert) {
    const data = generateIcsData("all day event", [
      { startsAt: "2026-03-12", allDay: true },
    ]);

    assert.true(data.includes("DTSTART;VALUE=DATE:20260312"));
    assert.true(
      data.includes("DTEND;VALUE=DATE:20260313"),
      "exclusive end is the day after the start"
    );
  });

  test("all-day Google url uses a date-only range", function (assert) {
    downloadGoogle("all day event", [
      { startsAt: "2026-03-12", endsAt: "2026-03-14", allDay: true },
    ]);

    assert.true(
      window.open.calledWith(
        "https://www.google.com/calendar/event?action=TEMPLATE&text=all+day+event&dates=20260312%2F20260315",
        "_blank",
        "noopener",
        "noreferrer"
      )
    );
  });

  test("formatDates preserves the all-day flag without adding a time", function (assert) {
    let dates = formatDates([{ startsAt: "2026-03-12", allDay: true }]);
    assert.deepEqual(dates, [
      { startsAt: "2026-03-12", endsAt: null, allDay: true },
    ]);
  });

  test("all-day ICS converts the RRULE UNTIL to a DATE value", function (assert) {
    const data = generateIcsData(
      "all day event",
      [{ startsAt: "2026-03-12", allDay: true }],
      { rrule: "FREQ=WEEKLY;BYDAY=TH;UNTIL=20260531T200000" }
    );

    assert.true(data.includes("DTSTART;VALUE=DATE:20260312"));
    assert.true(
      data.includes("RRULE:FREQ=WEEKLY;BYDAY=TH;UNTIL=20260531"),
      "UNTIL matches the DATE value type of DTSTART"
    );
    assert.false(
      data.includes("UNTIL=20260531T200000"),
      "UNTIL carries no time component"
    );
  });

  test("all-day Google url converts the RRULE UNTIL to a DATE value", function (assert) {
    downloadGoogle("event", [{ startsAt: "2026-03-12", allDay: true }], {
      rrule: "FREQ=WEEKLY;BYDAY=TH;UNTIL=20260531T200000Z",
    });

    const url = window.open.getCall(0).args[0];
    assert.true(url.includes("UNTIL%3D20260531"), "UNTIL is present as a date");
    assert.false(url.includes("20260531T"), "UNTIL carries no time component");
  });
});

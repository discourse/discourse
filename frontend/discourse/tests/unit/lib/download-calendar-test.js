import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  downloadGoogle,
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

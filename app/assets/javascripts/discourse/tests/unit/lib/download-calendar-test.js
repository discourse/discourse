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

  test("correct data for ICS", function (assert) {
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
        recurrenceRule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",
        location: "Paris",
        details: "Good soup",
      }
    );

    assert.strictEqual(
      data,
      `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Discourse//EN
BEGIN:VEVENT
UID:1634050800000_1634054400000
DTSTAMP:20220404T211500Z
DTSTART:20211012T150000Z
DTEND:20211012T160000Z
RRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR
LOCATION:Paris
DESCRIPTION:Good soup
SUMMARY:event test
END:VEVENT
END:VCALENDAR`
    );
  });

  test("correct data for ICS when recurring event", function (assert) {
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
      { recurrenceRule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR" }
    );
    assert.strictEqual(
      data,
      `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Discourse//EN
BEGIN:VEVENT
UID:1634050800000_1634054400000
DTSTAMP:20220404T211500Z
DTSTART:20211012T150000Z
DTEND:20211012T160000Z
RRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR
SUMMARY:event test
END:VEVENT
END:VCALENDAR`
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

  test("correct url for Google when recurring event", function (assert) {
    downloadGoogle(
      "event",
      [
        {
          startsAt: "2021-10-12T15:00:00.000Z",
          endsAt: "2021-10-12T16:00:00.000Z",
        },
      ],
      { recurrenceRule: "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR" }
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
});

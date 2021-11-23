import { module, test } from "qunit";
import {
  downloadGoogle,
  formatDates,
  generateIcsData,
} from "discourse/lib/download-calendar";
import sinon from "sinon";

module("Unit | Utility | download-calendar", function (hooks) {
  hooks.beforeEach(function () {
    let win = { focus: function () {} };
    sinon.stub(window, "open").returns(win);
    sinon.stub(win, "focus");
  });

  test("correct data for Ics", function (assert) {
    const data = generateIcsData("event test", [
      {
        startsAt: "2021-10-12T15:00:00.000Z",
        endsAt: "2021-10-12T16:00:00.000Z",
      },
    ]);
    assert.ok(
      data,
      `
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Discourse//EN
BEGIN:VEVENT
UID:1634050800000_1634054400000
DTSTAMP:20213312T223320Z
DTSTART:20210012T150000Z
DTEND:20210012T160000Z
SUMMARY:event2
END:VEVENT
END:VCALENDAR
    `
    );
  });

  test("correct url for Google", function (assert) {
    downloadGoogle("event", [
      {
        startsAt: "2021-10-12T15:00:00.000Z",
        endsAt: "2021-10-12T16:00:00.000Z",
      },
    ]);
    assert.ok(
      window.open.calledWith(
        "https://www.google.com/calendar/event?action=TEMPLATE&text=event&dates=20211012T150000Z/20211012T160000Z",
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

import { module, test } from "qunit";
import DateWithZoneHelper from "./date-with-zone-helper";

const PARIS = "Europe/Paris";
const SYDNEY = "Australia/Sydney";

function buildDateHelper(params = {}) {
  return new DateWithZoneHelper({
    year: params.year || 2020,
    day: params.day || 22,
    month: params.month || 2,
    hour: params.hour || 10,
    minute: params.minute || 5,
    timezone: params.timezone,
    localTimezone: PARIS,
  });
}

module("lib:date-with-zone-helper", function () {
  test("#format", function (assert) {
    let date = buildDateHelper({
      day: 15,
      month: 2,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });
    assert.strictEqual(date.format(), "2020-03-15T15:36:00.000+01:00");
  });

  test("#unitRepetitionsBetweenDates", function (assert) {
    let date;

    date = buildDateHelper({
      day: 15,
      month: 1,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });
    assert.strictEqual(
      date.unitRepetitionsBetweenDates(
        "1.hour",
        moment.tz("2020-02-15 15:36", SYDNEY)
      ),
      10,
      "it correctly finds difference between timezones"
    );

    date = buildDateHelper({
      day: 15,
      month: 1,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });
    assert.strictEqual(
      date.unitRepetitionsBetweenDates(
        "1.minute",
        moment.tz("2020-02-15 15:36", PARIS)
      ),
      0,
      "it correctly finds no difference"
    );

    date = buildDateHelper({
      day: 15,
      month: 1,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });
    assert.strictEqual(
      date.unitRepetitionsBetweenDates(
        "1.minute",
        moment.tz("2020-02-15 15:37", PARIS)
      ),
      1,
      "it correctly finds no difference"
    );

    date = buildDateHelper({
      day: 15,
      month: 1,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });
    assert.strictEqual(
      date.unitRepetitionsBetweenDates(
        "2.minutes",
        moment.tz("2020-02-15 15:41", PARIS)
      ),
      6,
      "it correctly finds difference with a multiplicator"
    );
  });

  test("#add", function (assert) {
    let date;
    let futureLocalDate;

    date = buildDateHelper({
      day: 19,
      month: 2,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });

    assert.false(date.isDST());
    futureLocalDate = date.add(8, "months");
    assert.false(futureLocalDate.isDST());
    assert.strictEqual(
      futureLocalDate.format(),
      "2020-11-19T15:36:00.000+01:00",
      "it correctly adds from a !isDST date to a !isDST date"
    );

    date = buildDateHelper({
      day: 25,
      month: 3,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });
    assert.ok(date.isDST());
    futureLocalDate = date.add(1, "year");
    assert.ok(futureLocalDate.isDST());
    assert.strictEqual(
      futureLocalDate.format(),
      "2021-04-25T15:36:00.000+02:00",
      "it correctly adds from a isDST date to a isDST date"
    );

    date = buildDateHelper({
      day: 25,
      month: 2,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });
    assert.false(date.isDST());
    futureLocalDate = date.add(1, "week");
    assert.ok(futureLocalDate.isDST());
    assert.strictEqual(
      futureLocalDate.format(),
      "2020-04-01T15:36:00.000+02:00",
      "it correctly adds from a !isDST date to a isDST date"
    );

    date = buildDateHelper({
      day: 1,
      month: 3,
      hour: 15,
      minute: 36,
      timezone: PARIS,
    });

    assert.ok(date.isDST());
    futureLocalDate = date.add(8, "months");
    assert.false(futureLocalDate.isDST());
    assert.strictEqual(
      futureLocalDate.format(),
      "2020-12-01T15:36:00.000+01:00",
      "it correctly adds from a isDST date to a !isDST date"
    );
  });
});

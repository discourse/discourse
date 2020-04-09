import DateWithZoneHelper from "./date-with-zone-helper";

const PARIS = "Europe/Paris";
const SYDNEY = "Australia/Sydney";

QUnit.module("lib:date-with-zone-helper");

function buildDateHelper(params = {}) {
  return new DateWithZoneHelper({
    year: params.year || 2020,
    day: params.day || 22,
    month: params.month || 2,
    hour: params.hour || 10,
    minute: params.minute || 5,
    timezone: params.timezone,
    localTimezone: PARIS
  });
}

QUnit.test("#format", assert => {
  let date = buildDateHelper({
    day: 15,
    month: 2,
    hour: 15,
    minute: 36,
    timezone: PARIS
  });
  assert.equal(date.format(), "2020-03-15T15:36:00.000+01:00");
});

QUnit.test("#repetitionsBetweenDates", assert => {
  let date;

  date = buildDateHelper({
    day: 15,
    month: 1,
    hour: 15,
    minute: 36,
    timezone: PARIS
  });
  assert.equal(
    date.repetitionsBetweenDates(
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
    timezone: PARIS
  });
  assert.equal(
    date.repetitionsBetweenDates(
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
    timezone: PARIS
  });
  assert.equal(
    date.repetitionsBetweenDates(
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
    timezone: PARIS
  });
  assert.equal(
    date.repetitionsBetweenDates(
      "2.minute",
      moment.tz("2020-02-15 15:41", PARIS)
    ),
    2.5,
    "it correctly finds difference with a multiplicator"
  );
});

QUnit.test("#add", assert => {
  let date;
  let futureLocalDate;

  date = buildDateHelper({
    day: 19,
    month: 2,
    hour: 15,
    minute: 36,
    timezone: PARIS
  });

  assert.notOk(date.isDST());
  futureLocalDate = date.add(8, "months");
  assert.notOk(futureLocalDate.isDST());
  assert.equal(
    futureLocalDate.format(),
    "2020-11-19T15:36:00.000+01:00",
    "it correctly adds from a !isDST date to a !isDST date"
  );

  date = buildDateHelper({
    day: 25,
    month: 3,
    hour: 15,
    minute: 36,
    timezone: PARIS
  });
  assert.ok(date.isDST());
  futureLocalDate = date.add(1, "year");
  assert.ok(futureLocalDate.isDST());
  assert.equal(
    futureLocalDate.format(),
    "2021-04-25T15:36:00.000+02:00",
    "it correctly adds from a isDST date to a isDST date"
  );

  date = buildDateHelper({
    day: 25,
    month: 2,
    hour: 15,
    minute: 36,
    timezone: PARIS
  });
  assert.notOk(date.isDST());
  futureLocalDate = date.add(1, "week");
  assert.ok(futureLocalDate.isDST());
  assert.equal(
    futureLocalDate.format(),
    "2020-04-01T15:36:00.000+02:00",
    "it correctly adds from a !isDST date to a isDST date"
  );

  date = buildDateHelper({
    day: 1,
    month: 3,
    hour: 15,
    minute: 36,
    timezone: PARIS
  });

  assert.ok(date.isDST());
  futureLocalDate = date.add(8, "months");
  assert.notOk(futureLocalDate.isDST());
  assert.equal(
    futureLocalDate.format(),
    "2020-12-01T15:36:00.000+01:00",
    "it correctly adds from a isDST date to a !isDST date"
  );
});

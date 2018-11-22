import { acceptance } from "helpers/qunit-helpers";

const sandbox = sinon.createSandbox();

acceptance("Local Dates", {
  loggedIn: true,
  settings: { discourse_local_dates_enabled: true },
  beforeEach() {
    freezeDateAndZone();
  },
  afterEach() {
    sandbox.restore();
    moment.tz.setDefault();
  }
});

const DEFAULT_DATE = "2018-06-20";
const DEFAULT_ZONE = "Europe/Paris";

function advance(count, unit = "days") {
  return moment(DEFAULT_DATE)
    .add(count, unit)
    .format("YYYY-MM-DD");
}

function rewind(count, unit = "days") {
  return moment(DEFAULT_DATE)
    .subtract(count, unit)
    .format("YYYY-MM-DD");
}

function freezeDateAndZone(date, zone, cb) {
  date = date || DEFAULT_DATE;
  zone = zone || DEFAULT_ZONE;

  sandbox.restore();
  sandbox.stub(moment.tz, "guess");
  moment.tz.guess.returns(zone);

  const now = moment(date).valueOf();
  sandbox.useFakeTimers(now);

  if (cb) {
    cb();

    moment.tz.guess.returns(DEFAULT_ZONE);
    sandbox.useFakeTimers(moment(DEFAULT_DATE).valueOf());
  }
}

function generateHTML(options = {}) {
  let output = `<span class="discourse-local-date past cooked-date"`;

  output += ` data-date="${options.date || DEFAULT_DATE}"`;
  if (options.format) output += ` data-format="${options.format}"`;
  if (options.time) output += ` data-time="${options.time}"`;
  if (options.calendar) output += ` data-calendar="${options.calendar}"`;
  if (options.recurring) output += ` data-recurring="${options.recurring}"`;
  if (options.displayedZone)
    output += ` data-displayed-zone="${options.displayedZone}"`;

  return (output += "></span>");
}

test("default format - time specified", assert => {
  const html = generateHTML({ date: advance(3), time: "00:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "June 23, 2018 2:00 AM",
    "it uses moment LLL format"
  );
});

test("default format - no time specified", assert => {
  const html = generateHTML({ date: advance(3) });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "June 23, 2018",
    "it uses moment LL format as default if not time is specified"
  );
});

test("today", assert => {
  const html = generateHTML({ time: "14:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(transformed.text(), "Today 4:00 PM", "it display Today");
});

test("today - no time", assert => {
  const html = generateHTML();
  const transformed = $(html).applyLocalDates();

  assert.equal(transformed.text(), "Today", "it display Today without time");
});

test("yesterday", assert => {
  const html = generateHTML({ date: rewind(1), time: "14:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "Yesterday 4:00 PM",
    "it displays yesterday"
  );
});

QUnit.skip("yesterday - no time", assert => {
  const html = generateHTML({ date: rewind(1) });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "Yesterday",
    "it displays yesterday without time"
  );
});

test("tomorrow", assert => {
  const html = generateHTML({ date: advance(1), time: "14:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(transformed.text(), "Tomorrow 4:00 PM", "it displays tomorrow");
});

test("tomorrow - no time", assert => {
  const html = generateHTML({ date: advance(1) });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "Tomorrow",
    "it displays tomorrow without time"
  );
});

test("today - no time with different zones", assert => {
  const html = generateHTML();
  let transformed = $(html).applyLocalDates();

  assert.equal(transformed.text(), "Today", "it displays today without time");

  freezeDateAndZone(rewind(12, "hours"), "Pacific/Auckland", () => {
    transformed = $(html).applyLocalDates();
    assert.equal(
      transformed.text(),
      "Tomorrow",
      "it displays Tomorrow without time"
    );
  });
});

test("calendar off", assert => {
  const html = generateHTML({ calendar: "off", time: "14:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "June 20, 2018 4:00 PM",
    "it displays the date without Today"
  );
});

test("recurring", assert => {
  const html = generateHTML({ recurring: "1.week", time: "14:00" });
  let transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "Today 4:00 PM",
    "it displays the next occurrence"
  );

  freezeDateAndZone(advance(1), () => {
    transformed = $(html).applyLocalDates();

    assert.equal(
      transformed.text(),
      "June 27, 2018 4:00 PM",
      "it displays the next occurrence"
    );
  });
});

test("displayedZone", assert => {
  const html = generateHTML({
    date: advance(3),
    displayedZone: "Etc/UTC",
    time: "14:00"
  });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "June 23, 2018 2:00 PM",
    "it forces display in the given timezone"
  );
});

test("format", assert => {
  const html = generateHTML({
    date: advance(3),
    format: "YYYY | MM - DD"
  });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text(),
    "2018 | 06 - 23",
    "it uses the given format"
  );
});

test("test utils", assert => {
  assert.equal(
    moment().format("LLLL"),
    moment(DEFAULT_DATE).format("LLLL"),
    "it has defaults"
  );
  assert.equal(moment.tz.guess(), DEFAULT_ZONE, "it has defaults");

  freezeDateAndZone(advance(1), DEFAULT_ZONE, () => {
    assert.equal(
      moment().format("LLLL"),
      moment(DEFAULT_DATE)
        .add(1, "days")
        .format("LLLL"),
      "it applies new time"
    );
    assert.equal(moment.tz.guess(), DEFAULT_ZONE);
  });

  assert.equal(
    moment().format("LLLL"),
    moment(DEFAULT_DATE).format("LLLL"),
    "it restores time"
  );

  freezeDateAndZone(advance(1), "Pacific/Auckland", () => {
    assert.equal(
      moment().format("LLLL"),
      moment(DEFAULT_DATE)
        .add(1, "days")
        .format("LLLL")
    );
    assert.equal(moment.tz.guess(), "Pacific/Auckland", "it applies new zone");
  });

  assert.equal(moment.tz.guess(), DEFAULT_ZONE, "it restores zone");
});

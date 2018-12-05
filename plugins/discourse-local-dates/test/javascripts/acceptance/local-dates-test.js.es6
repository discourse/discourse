import { acceptance } from "helpers/qunit-helpers";

const sandbox = sinon.createSandbox();

acceptance("Local Dates", {
  loggedIn: true,
  settings: {
    discourse_local_dates_enabled: true,
    discourse_local_dates_default_timezones: "Europe/Paris|America/Los_Angeles"
  },
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
const DEFAULT_ZONE_FORMATED = DEFAULT_ZONE.split("/")[1];

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
  moment.tz.setDefault(zone);

  const now = moment(date).valueOf();
  sandbox.useFakeTimers(now);

  if (cb) {
    cb();

    moment.tz.guess.returns(DEFAULT_ZONE);
    moment.tz.setDefault(DEFAULT_ZONE);
    sandbox.useFakeTimers(moment(DEFAULT_DATE).valueOf());
  }
}

function generateHTML(options = {}) {
  let output = `<span class="discourse-local-date past cooked-date"`;

  output += ` data-date="${options.date || DEFAULT_DATE}"`;
  if (options.format) output += ` data-format="${options.format}"`;
  if (options.timezones) output += ` data-timezones="${options.timezones}"`;
  if (options.time) output += ` data-time="${options.time}"`;
  output += ` data-timezone="${options.timezone || DEFAULT_ZONE}"`;
  if (options.calendar) output += ` data-calendar="${options.calendar}"`;
  if (options.recurring) output += ` data-recurring="${options.recurring}"`;
  if (options.displayedTimezone)
    output += ` data-displayed-timezone="${options.displayedTimezone}"`;

  return (output += "></span>");
}

test("default format - time specified", assert => {
  const html = generateHTML({ date: advance(3), time: "02:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "June 23, 2018 2:00 AM",
    "it uses moment LLL format"
  );
});

test("default format - no time specified", assert => {
  let html = generateHTML({ date: advance(3) });
  let transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "June 23, 2018",
    "it uses moment LL format as default if not time is specified"
  );

  freezeDateAndZone(advance(1), "Pacific/Auckland", () => {
    html = generateHTML({ date: advance(3) });
    transformed = $(html).applyLocalDates();

    assert.equal(
      transformed.text().trim(),
      `June 23, 2018 (${DEFAULT_ZONE_FORMATED})`,
      "it appends creator timezone if watching user timezone is different"
    );
  });

  freezeDateAndZone(advance(1), "Europe/Vienna", () => {
    html = generateHTML({ date: advance(3) });
    transformed = $(html).applyLocalDates();

    assert.equal(
      transformed.text().trim(),
      "June 23, 2018",
      "it doesn’t append timezone if different but with the same utc offset"
    );
  });
});

test("today", assert => {
  const html = generateHTML({ time: "16:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(transformed.text().trim(), "Today 4:00 PM", "it display Today");
});

test("today - no time", assert => {
  const html = generateHTML();
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Today",
    "it display Today without time"
  );
});

test("yesterday", assert => {
  const html = generateHTML({ date: rewind(1), time: "16:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Yesterday 4:00 PM",
    "it displays yesterday"
  );
});

test("yesterday - no time", assert => {
  const html = generateHTML({ date: rewind(1) });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Yesterday",
    "it displays yesterday without time"
  );
});

test("tomorrow", assert => {
  const html = generateHTML({ date: advance(1), time: "16:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Tomorrow 4:00 PM",
    "it displays tomorrow"
  );
});

test("tomorrow - no time", assert => {
  const html = generateHTML({ date: advance(1) });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Tomorrow",
    "it displays tomorrow without time"
  );
});

test("today - no time with different zones", assert => {
  const html = generateHTML();
  let transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Today",
    "it displays today without time"
  );

  freezeDateAndZone(rewind(12, "hours"), "Pacific/Auckland", () => {
    transformed = $(html).applyLocalDates();
    assert.equal(
      transformed.text().trim(),
      `June 20, 2018 (${DEFAULT_ZONE_FORMATED})`,
      "it displays the date without calendar and creator timezone"
    );
  });
});

test("calendar off", assert => {
  const html = generateHTML({ calendar: "off", time: "16:00" });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "June 20, 2018 4:00 PM",
    "it displays the date without Today"
  );
});

test("recurring", assert => {
  const html = generateHTML({ recurring: "1.week", time: "16:00" });
  let transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Today 4:00 PM",
    "it displays the next occurrence"
  );

  freezeDateAndZone(advance(1), null, () => {
    transformed = $(html).applyLocalDates();

    assert.equal(
      transformed.text().trim(),
      "June 27, 2018 4:00 PM",
      "it displays the next occurrence"
    );
  });
});

test("format", assert => {
  const html = generateHTML({
    date: advance(3),
    format: "YYYY | MM - DD"
  });
  const transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "2018 | 06 - 23",
    "it uses the given format"
  );
});

test("displayedTimezone", assert => {
  let html = generateHTML({
    date: advance(3),
    displayedTimezone: "America/Chicago",
    time: "16:00"
  });
  let transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "June 23, 2018 9:00 AM (Chicago)",
    "it displays timezone when different from watching user"
  );

  html = generateHTML({
    date: advance(3),
    displayedTimezone: DEFAULT_ZONE,
    time: "16:00"
  });

  transformed = $(html).applyLocalDates();
  assert.equal(
    transformed.text().trim(),
    "June 23, 2018 4:00 PM",
    "it doesn’t display timezone when same from watching user"
  );

  html = generateHTML({ displayedTimezone: "Etc/UTC" });
  transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "June 19, 2018 (UTC)",
    "it displays timezone and drops calendar mode when timezone is different from watching user"
  );

  html = generateHTML({ displayedTimezone: DEFAULT_ZONE });
  transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Today",
    "it doesn’t display timezone and doesn’t drop calendar mode when timezone is same from watching user"
  );

  html = generateHTML({
    timezone: "America/Chicago"
  });
  transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "June 20, 2018 (Chicago)",
    "it uses timezone when displayedTimezone is not set"
  );

  html = generateHTML();
  transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "Today",
    "it uses user’s timezone when displayedTimezone and timezone are not set"
  );

  html = generateHTML({
    timezone: "America/Chicago",
    displayedTimezone: "Pacific/Auckland"
  });
  transformed = $(html).applyLocalDates();

  assert.equal(
    transformed.text().trim(),
    "June 20, 2018 (Auckland)",
    "it uses displayedTimezone over timezone"
  );
});

test("tooltip", assert => {
  let html = generateHTML({ timezone: "America/Chicago" });
  let transformed = $(html).applyLocalDates();
  let htmlToolip = transformed.attr("data-html-tooltip");
  let currentUserPreview = $(htmlToolip).find(".preview.current");
  let timezone = currentUserPreview.find(".timezone").text();
  let dateTime = currentUserPreview.find(".date-time").text();

  assert.equal(
    timezone,
    DEFAULT_ZONE_FORMATED,
    "it adds watching user timezone as preview"
  );
  assert.equal(
    dateTime,
    "June 20, 2018 7:00 AM → June 21, 2018 7:00 AM",
    "it creates a range adjusted to watching user timezone"
  );

  freezeDateAndZone(DEFAULT_DATE, "Pacific/Auckland", () => {
    html = generateHTML({ timezone: "Pacific/Auckland" });
    transformed = $(html).applyLocalDates();
    htmlToolip = transformed.attr("data-html-tooltip");
    currentUserPreview = $(htmlToolip).find(".preview.current");

    assert.ok(
      exists(currentUserPreview),
      "it creates an entry if watching user has the same timezone than creator"
    );
  });

  html = generateHTML({
    timezones: "Etc/UTC",
    timezone: "America/Chicago",
    time: "14:00:00"
  });
  transformed = $(html).applyLocalDates();
  htmlToolip = transformed.attr("data-html-tooltip");

  assert.ok(
    exists($(htmlToolip).find(".preview.current")),
    "doesn’t create current timezone when displayed timezone equals watching user timezone"
  );

  let $firstPreview = $(htmlToolip).find(".preview:nth-child(2)");
  dateTime = $firstPreview.find(".date-time").text();
  timezone = $firstPreview.find(".timezone").text();
  assert.equal(
    dateTime,
    "June 20, 2018 2:00 PM",
    "it doesn’t create range if time has been set"
  );
  assert.equal(timezone, "Chicago", "it adds the timezone of the creator");

  let $secondPreview = $(htmlToolip).find(".preview:nth-child(3)");
  dateTime = $secondPreview.find(".date-time").text();
  timezone = $secondPreview.find(".timezone").text();
  assert.equal(timezone, "UTC", "Etc/UTC is rewritten to UTC");

  freezeDateAndZone(moment("2018-11-26 21:00:00"), "Europe/Vienna", () => {
    html = generateHTML({
      date: "2018-11-22",
      timezone: "America/Chicago",
      time: "14:00"
    });
    transformed = $(html).applyLocalDates();
    htmlToolip = transformed.attr("data-html-tooltip");

    $firstPreview = $(htmlToolip).find(".preview:nth-child(2)");

    assert.equal(
      $firstPreview.find(".timezone").text(),
      "Chicago",
      "it adds the creator timezone to the previews"
    );
    assert.equal(
      $firstPreview.find(".date-time").text(),
      "November 22, 2018 2:00 PM",
      "it adds the creator timezone to the previews"
    );
  });

  freezeDateAndZone(DEFAULT_DATE, "Europe/Vienna", () => {
    html = generateHTML({
      date: "2018-11-22",
      timezone: "America/Chicago",
      timezones: "Europe/Paris"
    });
    transformed = $(html).applyLocalDates();
    htmlToolip = transformed.attr("data-html-tooltip");

    $firstPreview = $(htmlToolip)
      .find(".preview")
      .first();

    assert.equal(
      $firstPreview.find(".timezone").text(),
      "Vienna",
      "it rewrites timezone with same offset and different name than watching user"
    );
  });
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

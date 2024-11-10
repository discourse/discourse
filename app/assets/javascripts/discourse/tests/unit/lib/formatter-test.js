import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  autoUpdatingRelativeAge,
  duration,
  durationTiny,
  longDate,
  number,
  relativeAge,
  until,
  updateRelativeAge,
} from "discourse/lib/formatter";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import domFromString from "discourse-common/lib/dom-from-string";

function formatMins(mins, opts = {}) {
  const dt = new Date(new Date() - mins * 60 * 1000);
  return relativeAge(dt, {
    format: opts.format || "tiny",
    leaveAgo: opts.leaveAgo,
  });
}

function formatHours(hours, opts) {
  return formatMins(hours * 60, opts);
}

function formatDays(days, opts) {
  return formatHours(days * 24, opts);
}

function shortDate(days) {
  return moment().subtract(days, "days").format("MMM D");
}

function shortDateTester(format) {
  return function (days) {
    return moment().subtract(days, "days").format(format);
  };
}

function strip(html) {
  return domFromString(html)[0].innerText;
}

module("Unit | Utility | formatter", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.clock = fakeTime("2012-12-31 12:00");
  });

  hooks.afterEach(function () {
    this.clock.restore();
  });

  test("formatting medium length dates", function (assert) {
    const shortDateYear = shortDateTester("MMM D, YYYY");

    assert.strictEqual(
      strip(formatMins(1.4, { format: "medium", leaveAgo: true })),
      "1 min ago"
    );
    assert.strictEqual(
      strip(formatMins(2, { format: "medium", leaveAgo: true })),
      "2 mins ago"
    );
    assert.strictEqual(
      strip(formatMins(55, { format: "medium", leaveAgo: true })),
      "55 mins ago"
    );
    assert.strictEqual(
      strip(formatMins(56, { format: "medium", leaveAgo: true })),
      "1 hour ago"
    );
    assert.strictEqual(
      strip(formatHours(4, { format: "medium", leaveAgo: true })),
      "4 hours ago"
    );
    assert.strictEqual(
      strip(formatHours(22, { format: "medium", leaveAgo: true })),
      "22 hours ago"
    );
    assert.strictEqual(
      strip(formatHours(23, { format: "medium", leaveAgo: true })),
      "23 hours ago"
    );
    assert.strictEqual(
      strip(formatHours(23.5, { format: "medium", leaveAgo: true })),
      "1 day ago"
    );
    assert.strictEqual(
      strip(formatDays(4.85, { format: "medium", leaveAgo: true })),
      "4 days ago"
    );

    assert.strictEqual(strip(formatMins(0, { format: "medium" })), "just now");
    assert.strictEqual(strip(formatMins(1.4, { format: "medium" })), "1 min");
    assert.strictEqual(strip(formatMins(2, { format: "medium" })), "2 mins");
    assert.strictEqual(strip(formatMins(55, { format: "medium" })), "55 mins");
    assert.strictEqual(strip(formatMins(56, { format: "medium" })), "1 hour");
    assert.strictEqual(strip(formatHours(4, { format: "medium" })), "4 hours");
    assert.strictEqual(
      strip(formatHours(22, { format: "medium" })),
      "22 hours"
    );
    assert.strictEqual(
      strip(formatHours(23, { format: "medium" })),
      "23 hours"
    );
    assert.strictEqual(strip(formatHours(23.5, { format: "medium" })), "1 day");
    assert.strictEqual(strip(formatDays(4.85, { format: "medium" })), "4 days");

    assert.strictEqual(
      strip(formatDays(6, { format: "medium" })),
      shortDate(6)
    );
    assert.strictEqual(
      strip(formatDays(100, { format: "medium" })),
      shortDate(100)
    ); // eg: Jan 23
    assert.strictEqual(
      strip(formatDays(500, { format: "medium" })),
      shortDateYear(500)
    );

    assert.strictEqual(
      domFromString(formatDays(0, { format: "medium" }))[0].title,
      longDate(new Date())
    );

    assert.ok(
      domFromString(formatDays(0, { format: "medium" }))[0].classList.contains(
        "date"
      )
    );

    this.clock.restore();
    this.clock = fakeTime("2012-01-09 12:00");

    assert.strictEqual(
      strip(formatDays(8, { format: "medium" })),
      shortDate(8)
    );
    assert.strictEqual(
      strip(formatDays(10, { format: "medium" })),
      shortDateYear(10)
    );
  });

  test("formatting tiny dates", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");

    const shortDateYear = shortDateTester("MMM YYYY");
    siteSettings.relative_date_duration = 14;

    assert.strictEqual(formatMins(0), "1m");
    assert.strictEqual(formatMins(1), "1m");
    assert.strictEqual(formatMins(2), "2m");
    assert.strictEqual(formatMins(60), "1h");
    assert.strictEqual(formatHours(4), "4h");
    assert.strictEqual(formatHours(23), "23h");
    assert.strictEqual(formatHours(23.5), "1d");
    assert.strictEqual(formatDays(1), "1d");
    assert.strictEqual(formatDays(14), "14d");
    assert.strictEqual(formatDays(15), shortDate(15));
    assert.strictEqual(formatDays(92), shortDate(92));
    assert.strictEqual(formatDays(364), shortDate(364));
    assert.strictEqual(formatDays(365), shortDate(365));
    assert.strictEqual(formatDays(366), shortDateYear(366)); // leap year
    assert.strictEqual(formatDays(500), shortDateYear(500));
    assert.strictEqual(formatDays(365 * 2 + 1), shortDateYear(365 * 2 + 1)); // one leap year

    assert.strictEqual(formatMins(-1), "1m");
    assert.strictEqual(formatMins(-2), "2m");
    assert.strictEqual(formatMins(-60), "1h");
    assert.strictEqual(formatHours(-4), "4h");
    assert.strictEqual(formatHours(-23), "23h");
    assert.strictEqual(formatHours(-23.5), "1d");
    assert.strictEqual(formatDays(-1), "1d");
    assert.strictEqual(formatDays(-14), "14d");
    assert.strictEqual(formatDays(-15), shortDateYear(-15));
    assert.strictEqual(formatDays(-92), shortDateYear(-92));
    assert.strictEqual(formatDays(-364), shortDateYear(-364));
    assert.strictEqual(formatDays(-365), shortDateYear(-365));
    assert.strictEqual(formatDays(-366), shortDateYear(-366)); // leap year
    assert.strictEqual(formatDays(-500), shortDateYear(-500));
    assert.strictEqual(formatDays(-365 * 2 - 1), shortDateYear(-365 * 2 - 1)); // one leap year

    const originalValue = siteSettings.relative_date_duration;
    siteSettings.relative_date_duration = 7;
    assert.strictEqual(formatDays(7), "7d");
    assert.strictEqual(formatDays(8), shortDate(8));

    siteSettings.relative_date_duration = 1;
    assert.strictEqual(formatDays(1), "1d");
    assert.strictEqual(formatDays(2), shortDate(2));

    siteSettings.relative_date_duration = 0;
    assert.strictEqual(formatMins(0), "1m");
    assert.strictEqual(formatMins(1), "1m");
    assert.strictEqual(formatMins(2), "2m");
    assert.strictEqual(formatMins(60), "1h");
    assert.strictEqual(formatDays(1), shortDate(1));
    assert.strictEqual(formatDays(2), shortDate(2));
    assert.strictEqual(formatDays(366), shortDateYear(366));

    siteSettings.relative_date_duration = null;
    assert.strictEqual(formatDays(1), "1d");
    assert.strictEqual(formatDays(14), "14d");
    assert.strictEqual(formatDays(15), shortDate(15));

    siteSettings.relative_date_duration = 14;

    this.clock.restore();
    this.clock = fakeTime("2012-01-12 12:00");

    assert.strictEqual(formatDays(11), "11d");
    assert.strictEqual(formatDays(14), "14d");
    assert.strictEqual(formatDays(15), shortDateYear(15));
    assert.strictEqual(formatDays(366), shortDateYear(366));

    this.clock.restore();
    this.clock = fakeTime("2012-01-20 12:00");

    assert.strictEqual(formatDays(14), "14d");
    assert.strictEqual(formatDays(15), shortDate(15));
    assert.strictEqual(formatDays(20), shortDateYear(20));

    siteSettings.relative_date_duration = originalValue;
  });

  test("autoUpdatingRelativeAge", function (assert) {
    const d = moment().subtract(1, "day").toDate();

    let elem = domFromString(autoUpdatingRelativeAge(d))[0];
    assert.strictEqual(elem.dataset.format, "tiny");
    assert.strictEqual(elem.dataset.time, d.getTime().toString());
    assert.strictEqual(elem.title, "");

    elem = domFromString(autoUpdatingRelativeAge(d, { title: true }))[0];
    assert.strictEqual(elem.title, longDate(d));

    elem = domFromString(
      autoUpdatingRelativeAge(d, {
        format: "medium",
        title: true,
        leaveAgo: true,
      })
    )[0];

    assert.strictEqual(elem.dataset.format, "medium-with-ago");
    assert.strictEqual(elem.dataset.time, d.getTime().toString());
    assert.strictEqual(elem.title, longDate(d));
    assert.dom(elem).hasHtml("1 day ago");

    elem = domFromString(autoUpdatingRelativeAge(d, { format: "medium" }))[0];
    assert.strictEqual(elem.dataset.format, "medium");
    assert.strictEqual(elem.dataset.time, d.getTime().toString());
    assert.strictEqual(elem.title, "");
    assert.dom(elem).hasHtml("1 day");

    elem = domFromString(autoUpdatingRelativeAge(d, { prefix: "test" }))[0];
    assert.dom(elem).hasHtml("test 1d");
  });

  test("updateRelativeAge", function (assert) {
    let d = new Date();
    let elem = domFromString(autoUpdatingRelativeAge(d))[0];
    elem.dataset.time = d.getTime() - 2 * 60 * 1000;

    updateRelativeAge(elem);

    assert.dom(elem).hasHtml("2m");

    d = new Date();
    elem = domFromString(
      autoUpdatingRelativeAge(d, { format: "medium", leaveAgo: true })
    )[0];
    elem.dataset.time = d.getTime() - 2 * 60 * 1000;

    updateRelativeAge(elem);

    assert.dom(elem).hasHtml("2 mins ago");
  });

  test("number", function (assert) {
    assert.strictEqual(
      number(123),
      "123",
      "it returns a string version of the number"
    );
    assert.strictEqual(number("123"), "123", "it works with a string command");
    assert.strictEqual(number(NaN), "0", "it returns 0 for NaN");
    assert.strictEqual(number(3333), "3.3k", "it abbreviates thousands");
    assert.strictEqual(number(2499999), "2.5M", "it abbreviates millions");
    assert.strictEqual(number("2499999.5"), "2.5M", "it abbreviates millions");
    assert.strictEqual(number(1000000), "1.0M", "it abbreviates a million");
    assert.strictEqual(
      number(999999),
      "999k",
      "it abbreviates hundreds of thousands"
    );
    assert.strictEqual(
      number(18.2),
      "18",
      "it returns a float number rounded to an integer as a string"
    );
    assert.strictEqual(
      number(18.6),
      "19",
      "it returns a float number rounded to an integer as a string"
    );
    assert.strictEqual(
      number("12.3"),
      "12",
      "it returns a string float rounded to an integer as a string"
    );
    assert.strictEqual(
      number("12.6"),
      "13",
      "it returns a string float rounded to an integer as a string"
    );
  });

  test("durationTiny", function (assert) {
    assert.strictEqual(durationTiny(), "&mdash;", "undefined is a dash");
    assert.strictEqual(durationTiny(null), "&mdash;", "null is a dash");
    assert.strictEqual(durationTiny(0), "< 1m", "0 seconds shows as < 1m");
    assert.strictEqual(durationTiny(59), "< 1m", "59 seconds shows as < 1m");
    assert.strictEqual(durationTiny(60), "1m", "60 seconds shows as 1m");
    assert.strictEqual(durationTiny(90), "2m", "90 seconds shows as 2m");
    assert.strictEqual(durationTiny(120), "2m", "120 seconds shows as 2m");
    assert.strictEqual(durationTiny(60 * 45), "1h", "45 minutes shows as 1h");
    assert.strictEqual(durationTiny(60 * 60), "1h", "60 minutes shows as 1h");
    assert.strictEqual(durationTiny(60 * 90), "2h", "90 minutes shows as 2h");
    assert.strictEqual(durationTiny(3600 * 23), "23h", "23 hours shows as 23h");
    assert.strictEqual(
      durationTiny(3600 * 24 - 29),
      "1d",
      "23 hours 31 mins shows as 1d"
    );
    assert.strictEqual(
      durationTiny(3600 * 24 * 89),
      "89d",
      "89 days shows as 89d"
    );
    assert.strictEqual(
      durationTiny(60 * (525600 - 1)),
      "12mon",
      "364 days shows as 12mon"
    );
    assert.strictEqual(durationTiny(60 * 525600), "1y", "365 days shows as 1y");
    assert.strictEqual(durationTiny(86400 * 456), "1y", "456 days shows as 1y");
    assert.strictEqual(
      durationTiny(86400 * 457),
      "> 1y",
      "457 days shows as > 1y"
    );
    assert.strictEqual(
      durationTiny(86400 * 638),
      "> 1y",
      "638 days shows as > 1y"
    );
    assert.strictEqual(durationTiny(86400 * 639), "2y", "639 days shows as 2y");
    assert.strictEqual(durationTiny(86400 * 821), "2y", "821 days shows as 2y");
    assert.strictEqual(
      durationTiny(86400 * 822),
      "> 2y",
      "822 days shows as > 2y"
    );
  });

  test("duration (medium format)", function (assert) {
    assert.strictEqual(
      duration(undefined, { format: "medium" }),
      "&mdash;",
      "undefined is a dash"
    );
    assert.strictEqual(
      duration(null, { format: "medium" }),
      "&mdash;",
      "null is a dash"
    );
    assert.strictEqual(
      duration(0, { format: "medium" }),
      "less than 1 min",
      "0 seconds shows as less than 1 min"
    );
    assert.strictEqual(
      duration(59, { format: "medium" }),
      "less than 1 min",
      "59 seconds shows as less than 1 min"
    );
    assert.strictEqual(
      duration(60, { format: "medium" }),
      "1 min",
      "60 seconds shows as 1 min"
    );
    assert.strictEqual(
      duration(90, { format: "medium" }),
      "2 mins",
      "90 seconds shows as 2 mins"
    );
    assert.strictEqual(
      duration(120, { format: "medium" }),
      "2 mins",
      "120 seconds shows as 2 mins"
    );
    assert.strictEqual(
      duration(60 * 45, { format: "medium" }),
      "about 1 hour",
      "45 minutes shows as about 1 hour"
    );
    assert.strictEqual(
      duration(60 * 60, { format: "medium" }),
      "about 1 hour",
      "60 minutes shows as about 1 hour"
    );
    assert.strictEqual(
      duration(60 * 90, { format: "medium" }),
      "about 2 hours",
      "90 minutes shows as about 2 hours"
    );
    assert.strictEqual(
      duration(3600 * 23, { format: "medium" }),
      "about 23 hours",
      "23 hours shows as about 23 hours"
    );
    assert.strictEqual(
      duration(3600 * 24 - 29, { format: "medium" }),
      "1 day",
      "23 hours 31 mins shows as 1 day"
    );
    assert.strictEqual(
      duration(3600 * 24 * 89, { format: "medium" }),
      "89 days",
      "89 days shows as 89 days"
    );
    assert.strictEqual(
      duration(60 * (525600 - 1), { format: "medium" }),
      "12 months",
      "364 days shows as 12 months"
    );
    assert.strictEqual(
      duration(60 * 525600, { format: "medium" }),
      "about 1 year",
      "365 days shows as about 1 year"
    );
    assert.strictEqual(
      duration(86400 * 456, { format: "medium" }),
      "about 1 year",
      "456 days shows as about 1 year"
    );
    assert.strictEqual(
      duration(86400 * 457, { format: "medium" }),
      "over 1 year",
      "457 days shows as over 1 year"
    );
    assert.strictEqual(
      duration(86400 * 638, { format: "medium" }),
      "over 1 year",
      "638 days shows as over 1 year"
    );
    assert.strictEqual(
      duration(86400 * 639, { format: "medium" }),
      "almost 2 years",
      "639 days shows as almost 2 years"
    );
    assert.strictEqual(
      duration(86400 * 821, { format: "medium" }),
      "about 2 years",
      "821 days shows as about 2 years"
    );
    assert.strictEqual(
      duration(86400 * 822, { format: "medium" }),
      "over 2 years",
      "822 days shows as over 2 years"
    );
  });
});

module("Unit | Utility | formatter | until", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    this.clock?.restore();
  });

  test("shows time if until moment is today", function (assert) {
    const timezone = "UTC";
    this.clock = fakeTime("2100-01-01 12:00:00.000Z", timezone);
    const result = until("2100-01-01 13:00:00.000Z", timezone, "en");
    assert.strictEqual(result, "Until: 1:00 PM");
  });

  test("shows date if until moment is tomorrow", function (assert) {
    const timezone = "UTC";
    this.clock = fakeTime("2100-01-01 12:00:00.000Z", timezone);
    const result = until("2100-01-02 12:00:00.000Z", timezone, "en");
    assert.strictEqual(result, "Until: Jan 2");
  });

  test("shows until moment in user's timezone", function (assert) {
    const timezone = "Asia/Tbilisi";
    const untilUTC = "13:00";
    const untilTbilisi = "5:00 PM";

    this.clock = fakeTime("2100-01-01 12:00:00.000Z", timezone);
    const result = until(`2100-01-01 ${untilUTC}:00.000Z`, timezone, "en");

    assert.strictEqual(result, `Until: ${untilTbilisi}`);
  });
});

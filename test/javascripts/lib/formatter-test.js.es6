var clock;

import {
  relativeAge,
  autoUpdatingRelativeAge,
  updateRelativeAge,
  breakUp,
  number,
  longDate,
  durationTiny
} from "discourse/lib/formatter";

QUnit.module("lib:formatter", {
  beforeEach() {
    clock = sinon.useFakeTimers(new Date(2012, 11, 31, 12, 0).getTime());
  },

  afterEach() {
    clock.restore();
  }
});

var format = "tiny";
var leaveAgo = false;
var mins_ago = function(mins) {
  return new Date(new Date() - mins * 60 * 1000);
};

var formatMins = function(mins) {
  return relativeAge(mins_ago(mins), { format: format, leaveAgo: leaveAgo });
};

var formatHours = function(hours) {
  return formatMins(hours * 60);
};

var formatDays = function(days) {
  return formatHours(days * 24);
};

var shortDate = function(days) {
  return moment()
    .subtract(days, "days")
    .format("MMM D");
};

QUnit.test("formating medium length dates", assert => {
  format = "medium";
  var strip = function(html) {
    return $(html).text();
  };

  var shortDateYear = function(days) {
    return moment()
      .subtract(days, "days")
      .format("MMM D, 'YY");
  };

  leaveAgo = true;
  assert.equal(strip(formatMins(1.4)), "1 min ago");
  assert.equal(strip(formatMins(2)), "2 mins ago");
  assert.equal(strip(formatMins(55)), "55 mins ago");
  assert.equal(strip(formatMins(56)), "1 hour ago");
  assert.equal(strip(formatHours(4)), "4 hours ago");
  assert.equal(strip(formatHours(22)), "22 hours ago");
  assert.equal(strip(formatHours(23)), "23 hours ago");
  assert.equal(strip(formatHours(23.5)), "1 day ago");
  assert.equal(strip(formatDays(4.85)), "4 days ago");

  leaveAgo = false;
  assert.equal(strip(formatMins(0)), "just now");
  assert.equal(strip(formatMins(1.4)), "1 min");
  assert.equal(strip(formatMins(2)), "2 mins");
  assert.equal(strip(formatMins(55)), "55 mins");
  assert.equal(strip(formatMins(56)), "1 hour");
  assert.equal(strip(formatHours(4)), "4 hours");
  assert.equal(strip(formatHours(22)), "22 hours");
  assert.equal(strip(formatHours(23)), "23 hours");
  assert.equal(strip(formatHours(23.5)), "1 day");
  assert.equal(strip(formatDays(4.85)), "4 days");

  assert.equal(strip(formatDays(6)), shortDate(6));
  assert.equal(strip(formatDays(100)), shortDate(100)); // eg: Jan 23
  assert.equal(strip(formatDays(500)), shortDateYear(500));

  assert.equal($(formatDays(0)).attr("title"), longDate(new Date()));
  assert.equal($(formatDays(0)).attr("class"), "date");

  clock.restore();
  clock = sinon.useFakeTimers(new Date(2012, 0, 9, 12, 0).getTime()); // Jan 9, 2012

  assert.equal(strip(formatDays(8)), shortDate(8));
  assert.equal(strip(formatDays(10)), shortDateYear(10));
});

QUnit.test("formating tiny dates", assert => {
  var shortDateYear = function(days) {
    return moment()
      .subtract(days, "days")
      .format("MMM 'YY");
  };

  format = "tiny";
  assert.equal(formatMins(0), "1m");
  assert.equal(formatMins(1), "1m");
  assert.equal(formatMins(2), "2m");
  assert.equal(formatMins(60), "1h");
  assert.equal(formatHours(4), "4h");
  assert.equal(formatHours(23), "23h");
  assert.equal(formatHours(23.5), "1d");
  assert.equal(formatDays(1), "1d");
  assert.equal(formatDays(14), "14d");
  assert.equal(formatDays(15), shortDate(15));
  assert.equal(formatDays(92), shortDate(92));
  assert.equal(formatDays(364), shortDate(364));
  assert.equal(formatDays(365), shortDate(365));
  assert.equal(formatDays(366), shortDateYear(366)); // leap year
  assert.equal(formatDays(500), shortDateYear(500));
  assert.equal(formatDays(365 * 2 + 1), shortDateYear(365 * 2 + 1)); // one leap year

  var originalValue = Discourse.SiteSettings.relative_date_duration;
  Discourse.SiteSettings.relative_date_duration = 7;
  assert.equal(formatDays(7), "7d");
  assert.equal(formatDays(8), shortDate(8));

  Discourse.SiteSettings.relative_date_duration = 1;
  assert.equal(formatDays(1), "1d");
  assert.equal(formatDays(2), shortDate(2));

  Discourse.SiteSettings.relative_date_duration = 0;
  assert.equal(formatMins(0), "1m");
  assert.equal(formatMins(1), "1m");
  assert.equal(formatMins(2), "2m");
  assert.equal(formatMins(60), "1h");
  assert.equal(formatDays(1), shortDate(1));
  assert.equal(formatDays(2), shortDate(2));
  assert.equal(formatDays(366), shortDateYear(366));

  Discourse.SiteSettings.relative_date_duration = null;
  assert.equal(formatDays(1), "1d");
  assert.equal(formatDays(14), "14d");
  assert.equal(formatDays(15), shortDate(15));

  Discourse.SiteSettings.relative_date_duration = 14;

  clock.restore();
  clock = sinon.useFakeTimers(new Date(2012, 0, 12, 12, 0).getTime()); // Jan 12, 2012

  assert.equal(formatDays(11), "11d");
  assert.equal(formatDays(14), "14d");
  assert.equal(formatDays(15), shortDateYear(15));
  assert.equal(formatDays(366), shortDateYear(366));

  clock.restore();
  clock = sinon.useFakeTimers(new Date(2012, 0, 20, 12, 0).getTime()); // Jan 20, 2012

  assert.equal(formatDays(14), "14d");
  assert.equal(formatDays(15), shortDate(15));
  assert.equal(formatDays(20), shortDateYear(20));

  Discourse.SiteSettings.relative_date_duration = originalValue;
});

QUnit.test("autoUpdatingRelativeAge", assert => {
  var d = moment()
    .subtract(1, "day")
    .toDate();

  var $elem = $(autoUpdatingRelativeAge(d));
  assert.equal($elem.data("format"), "tiny");
  assert.equal($elem.data("time"), d.getTime());
  assert.equal($elem.attr("title"), undefined);

  $elem = $(autoUpdatingRelativeAge(d, { title: true }));
  assert.equal($elem.attr("title"), longDate(d));

  $elem = $(
    autoUpdatingRelativeAge(d, {
      format: "medium",
      title: true,
      leaveAgo: true
    })
  );
  assert.equal($elem.data("format"), "medium-with-ago");
  assert.equal($elem.data("time"), d.getTime());
  assert.equal($elem.attr("title"), longDate(d));
  assert.equal($elem.html(), "1 day ago");

  $elem = $(autoUpdatingRelativeAge(d, { format: "medium" }));
  assert.equal($elem.data("format"), "medium");
  assert.equal($elem.data("time"), d.getTime());
  assert.equal($elem.attr("title"), undefined);
  assert.equal($elem.html(), "1 day");
});

QUnit.test("updateRelativeAge", assert => {
  var d = new Date();
  var $elem = $(autoUpdatingRelativeAge(d));
  $elem.data("time", d.getTime() - 2 * 60 * 1000);

  updateRelativeAge($elem);

  assert.equal($elem.html(), "2m");

  d = new Date();
  $elem = $(autoUpdatingRelativeAge(d, { format: "medium", leaveAgo: true }));
  $elem.data("time", d.getTime() - 2 * 60 * 1000);

  updateRelativeAge($elem);

  assert.equal($elem.html(), "2 mins ago");
});

QUnit.test("breakUp", assert => {
  var b = function(s, hint) {
    return breakUp(s, hint);
  };

  assert.equal(b("hello"), "hello");
  assert.equal(b("helloworld"), "helloworld");
  assert.equal(b("HeMans11"), "He<wbr>&#8203;Mans<wbr>&#8203;11");
  assert.equal(b("he_man"), "he_<wbr>&#8203;man");
  assert.equal(b("he11111"), "he<wbr>&#8203;11111");
  assert.equal(b("HRCBob"), "HRC<wbr>&#8203;Bob");
  assert.equal(
    b("bobmarleytoo", "Bob Marley Too"),
    "bob<wbr>&#8203;marley<wbr>&#8203;too"
  );
});

QUnit.test("number", assert => {
  assert.equal(number(123), "123", "it returns a string version of the number");
  assert.equal(number("123"), "123", "it works with a string command");
  assert.equal(number(NaN), "0", "it returns 0 for NaN");
  assert.equal(number(3333), "3.3k", "it abbreviates thousands");
  assert.equal(number(2499999), "2.5M", "it abbreviates millions");
  assert.equal(number("2499999.5"), "2.5M", "it abbreviates millions");
  assert.equal(number(1000000), "1.0M", "it abbreviates a million");
  assert.equal(number(999999), "999k", "it abbreviates hundreds of thousands");
  assert.equal(
    number(18.2),
    "18",
    "it returns a float number rounded to an integer as a string"
  );
  assert.equal(
    number(18.6),
    "19",
    "it returns a float number rounded to an integer as a string"
  );
  assert.equal(
    number("12.3"),
    "12",
    "it returns a string float rounded to an integer as a string"
  );
  assert.equal(
    number("12.6"),
    "13",
    "it returns a string float rounded to an integer as a string"
  );
});

QUnit.test("durationTiny", assert => {
  assert.equal(durationTiny(), "&mdash;", "undefined is a dash");
  assert.equal(durationTiny(null), "&mdash;", "null is a dash");
  assert.equal(durationTiny(0), "< 1m", "0 seconds shows as < 1m");
  assert.equal(durationTiny(59), "< 1m", "59 seconds shows as < 1m");
  assert.equal(durationTiny(60), "1m", "60 seconds shows as 1m");
  assert.equal(durationTiny(90), "2m", "90 seconds shows as 2m");
  assert.equal(durationTiny(120), "2m", "120 seconds shows as 2m");
  assert.equal(durationTiny(60 * 45), "1h", "45 minutes shows as 1h");
  assert.equal(durationTiny(60 * 60), "1h", "60 minutes shows as 1h");
  assert.equal(durationTiny(60 * 90), "2h", "90 minutes shows as 2h");
  assert.equal(durationTiny(3600 * 23), "23h", "23 hours shows as 23h");
  assert.equal(
    durationTiny(3600 * 24 - 29),
    "1d",
    "23 hours 31 mins shows as 1d"
  );
  assert.equal(durationTiny(3600 * 24 * 89), "89d", "89 days shows as 89d");
  assert.equal(
    durationTiny(60 * (525600 - 1)),
    "12mon",
    "364 days shows as 12mon"
  );
  assert.equal(durationTiny(60 * 525600), "1y", "365 days shows as 1y");
  assert.equal(durationTiny(86400 * 456), "1y", "456 days shows as 1y");
  assert.equal(durationTiny(86400 * 457), "> 1y", "457 days shows as > 1y");
  assert.equal(durationTiny(86400 * 638), "> 1y", "638 days shows as > 1y");
  assert.equal(durationTiny(86400 * 639), "2y", "639 days shows as 2y");
  assert.equal(durationTiny(86400 * 821), "2y", "821 days shows as 2y");
  assert.equal(durationTiny(86400 * 822), "> 2y", "822 days shows as > 2y");
});

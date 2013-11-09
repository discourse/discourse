var clock;

module("Discourse.Formatter", {
  setup: function() {
    clock = sinon.useFakeTimers(new Date(2012,11,31,12,0).getTime());
  },

  teardown: function() {
    clock.restore();
  }
});

var format = "tiny";
var leaveAgo = false;
var mins_ago = function(mins){
  return new Date((new Date()) - mins * 60 * 1000);
};

var formatMins = function(mins) {
  return Discourse.Formatter.relativeAge(mins_ago(mins), {format: format, leaveAgo: leaveAgo});
};

var formatHours = function(hours) {
  return formatMins(hours * 60);
};

var formatDays = function(days) {
  return formatHours(days * 24);
};

var formatMonths = function(months) {
  return formatDays(months * 30);
};

var shortDate = function(days){
  return moment().subtract('days', days).format('D MMM');
};

test("formating medium length dates", function() {

  format = "medium";
  var strip = function(html){
    return $(html).text();
  };

  var shortDateYear = function(days){
    return moment().subtract('days', days).format('D MMM, YYYY');
  };

  leaveAgo = true;
  equal(strip(formatMins(1.4)), "1 min ago");
  equal(strip(formatMins(2)), "2 mins ago");
  equal(strip(formatMins(56)), "56 mins ago");
  equal(strip(formatMins(57)), "1 hour ago");
  equal(strip(formatHours(4)), "4 hours ago");
  equal(strip(formatHours(22)), "22 hours ago");
  equal(strip(formatHours(23)), "1 day ago");
  equal(strip(formatDays(4.85)), "4 days ago");

  leaveAgo = false;
  equal(strip(formatMins(0)), "just now");
  equal(strip(formatMins(1.4)), "1 min");
  equal(strip(formatMins(2)), "2 mins");
  equal(strip(formatMins(56)), "56 mins");
  equal(strip(formatMins(57)), "1 hour");
  equal(strip(formatHours(4)), "4 hours");
  equal(strip(formatHours(22)), "22 hours");
  equal(strip(formatHours(23)), "1 day");
  equal(strip(formatDays(4.85)), "4 days");

  equal(strip(formatDays(6)), shortDate(6));
  equal(strip(formatDays(100)), shortDate(100)); // eg: 23 Jan
  equal(strip(formatDays(500)), shortDateYear(500));

  equal($(formatDays(0)).attr("title"), moment().format('MMMM D, YYYY h:mma'));
  equal($(formatDays(0)).attr("class"), "date");

  clock.restore();
  clock = sinon.useFakeTimers(new Date(2012,0,9,12,0).getTime()); // Jan 9, 2012

  equal(strip(formatDays(8)), shortDate(8));
  equal(strip(formatDays(10)), shortDateYear(10));

});

test("formating tiny dates", function() {
  var shortDateYear = function(days){
    return moment().subtract('days', days).format("D MMM 'YY");
  };

  format = "tiny";
  equal(formatMins(0), "< 1m");
  equal(formatMins(2), "2m");
  equal(formatMins(60), "1h");
  equal(formatHours(4), "4h");
  equal(formatDays(1), "1d");
  equal(formatDays(14), "14d");
  equal(formatDays(15), shortDate(15));
  equal(formatDays(92), shortDate(92));
  equal(formatDays(364), shortDate(364));
  equal(formatDays(365), shortDate(365));
  equal(formatDays(366), shortDateYear(366)); // leap year
  equal(formatDays(500), shortDateYear(500));
  equal(formatDays(365*2 + 1), shortDateYear(365*2 + 1)); // one leap year

  var originalValue = Discourse.SiteSettings.relative_date_duration;
  Discourse.SiteSettings.relative_date_duration = 7;
  equal(formatDays(7), "7d");
  equal(formatDays(8), shortDate(8));

  Discourse.SiteSettings.relative_date_duration = 1;
  equal(formatDays(1), "1d");
  equal(formatDays(2), shortDate(2));

  Discourse.SiteSettings.relative_date_duration = 0;
  equal(formatMins(0), "< 1m");
  equal(formatMins(2), "2m");
  equal(formatMins(60), "1h");
  equal(formatDays(1), shortDate(1));
  equal(formatDays(2), shortDate(2));
  equal(formatDays(366), shortDateYear(366));

  Discourse.SiteSettings.relative_date_duration = null;
  equal(formatDays(1), '1d');
  equal(formatDays(14), '14d');
  equal(formatDays(15), shortDate(15));

  Discourse.SiteSettings.relative_date_duration = 14;

  clock.restore();
  clock = sinon.useFakeTimers(new Date(2012,0,12,12,0).getTime()); // Jan 12, 2012

  equal(formatDays(11), "11d");
  equal(formatDays(14), "14d");
  equal(formatDays(15), shortDateYear(15));
  equal(formatDays(366), shortDateYear(366));

  clock.restore();
  clock = sinon.useFakeTimers(new Date(2012,0,20,12,0).getTime()); // Jan 20, 2012

  equal(formatDays(14), "14d");
  equal(formatDays(15), shortDate(15));
  equal(formatDays(20), shortDateYear(20));

  Discourse.SiteSettings.relative_date_duration = originalValue;
});

module("Discourse.Formatter");

test("autoUpdatingRelativeAge", function() {
  var d = moment().subtract('days',1).toDate();

  var $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d));
  equal($elem.data('format'), "tiny");
  equal($elem.data('time'), d.getTime());
  equal($elem.attr('title'), undefined);

  $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d, {title: true}));
  equal($elem.attr('title'), moment(d).longDate());

  $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d,{format: 'medium', title: true, leaveAgo: true}));
  equal($elem.data('format'), "medium-with-ago");
  equal($elem.data('time'), d.getTime());
  equal($elem.attr('title'), moment(d).longDate());
  equal($elem.html(), '1 day ago');

  $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d,{format: 'medium'}));
  equal($elem.data('format'), "medium");
  equal($elem.data('time'), d.getTime());
  equal($elem.attr('title'), undefined);
  equal($elem.html(), '1 day');
});

test("updateRelativeAge", function(){

  var d = new Date();
  var $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d));
  $elem.data('time', d.getTime() - 2 * 60 * 1000);

  Discourse.Formatter.updateRelativeAge($elem);

  equal($elem.html(), "2m");

  d = new Date();
  $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d, {format: 'medium', leaveAgo: true}));
  $elem.data('time', d.getTime() - 2 * 60 * 1000);

  Discourse.Formatter.updateRelativeAge($elem);

  equal($elem.html(), "2 mins ago");
});

test("breakUp", function(){

  var b = function(s){ return Discourse.Formatter.breakUp(s,5); };

  equal(b("hello"), "hello");
  equal(b("helloworld"), "hello world");
  equal(b("HeMans"), "He Mans");
  equal(b("he_man"), "he_ man");
  equal(b("he11111"), "he 11111");
  equal(b("HRCBob"), "HRC Bob");

});

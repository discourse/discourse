/*global module:true test:true ok:true visit:true equal:true exists:true count:true equal:true present:true md5:true */

module("Discourse.Formatter");

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

test("formating medium length dates", function() {

  format = "medium";
  var strip = function(html){
    return $(html).text();
  }

  var shortDate = function(days){
    return moment().subtract('days', days).format('D MMM');
  }

  var shortDateYear = function(days){
    return moment().subtract('days', days).format('D MMM, YYYY');
  }

  leaveAgo = true;
  equal(strip(formatMins(1.4)), "1 minute ago");
  equal(strip(formatMins(2)), "2 minutes ago");
  equal(strip(formatMins(56)), "56 minutes ago");
  equal(strip(formatMins(57)), "1 hour ago");
  equal(strip(formatHours(4)), "4 hours ago");
  equal(strip(formatHours(22)), "22 hours ago");
  equal(strip(formatHours(23)), "1 day ago");
  equal(strip(formatDays(4.85)), "4 days ago");

  leaveAgo = false;
  equal(strip(formatMins(0)), "just now");
  equal(strip(formatMins(1.4)), "1 minute");
  equal(strip(formatMins(2)), "2 minutes");
  equal(strip(formatMins(56)), "56 minutes");
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

});

test("formating tiny dates", function() {
  format = "tiny";
  equal(formatMins(0), "< 1m");
  equal(formatMins(2), "2m");
  equal(formatMins(60), "1h");
  equal(formatHours(4), "4h");
  equal(formatDays(1), "1d");
  equal(formatDays(20), "20d");
  equal(formatMonths(3), "3mon");
  equal(formatMonths(23), "23mon");
  equal(formatMonths(24), "> 2y");
});

test("autoUpdatingRelativeAge", function() {
  var d = moment().subtract('days',1).toDate();

  var $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d));
  equal($elem.data('format'), "tiny");
  equal($elem.data('time'), d.getTime());

  $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d,{format: 'medium', leaveAgo: true}));
  equal($elem.data('format'), "medium-with-ago");
  equal($elem.data('time'), d.getTime());
  equal($elem.attr('title'), moment(d).longDate());
  equal($elem.html(), '1 day ago');

  $elem = $(Discourse.Formatter.autoUpdatingRelativeAge(d,{format: 'medium'}));
  equal($elem.data('format'), "medium");
  equal($elem.data('time'), d.getTime());
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

  equal($elem.html(), "2 minutes ago");
});

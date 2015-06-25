/* global BreakString:true */

var updateRelativeAge, autoUpdatingRelativeAge, relativeAge, relativeAgeTiny,
    relativeAgeMedium, relativeAgeMediumSpan, longDate, longDateNoYear, toTitleCase,
    shortDate, shortDateNoYear, tinyDateYear, relativeAgeTinyShowsYear;

/*
* memoize.js
* by @philogb and @addyosmani
* with further optimizations by @mathias
* and @DmitryBaranovsk
* perf tests: http://bit.ly/q3zpG3
* Released under an MIT license.
*
* modified with cap by Sam
*/
var cappedMemoize = function ( fn, max ) {
    fn.maxMemoize = max;
    fn.memoizeLength = 0;

    return function () {
        var args = Array.prototype.slice.call(arguments),
            hash = "",
            i = args.length;
        var currentArg = null;
        while (i--) {
            currentArg = args[i];
            hash += (currentArg === new Object(currentArg)) ?
            JSON.stringify(currentArg) : currentArg;
            if(!fn.memoize) {
              fn.memoize = {};
            }
        }
        if (hash in fn.memoize) {
          return fn.memoize[hash];
        } else {
          fn.memoizeLength++;
          if(fn.memoizeLength > max) {
            fn.memoizeLength = 0;
            fn.memoize = {};
          }
          var result = fn.apply(this, args);
          fn.memoize[hash] = result;
          return result;
        }
    };
};

var breakUp = cappedMemoize(function(str, hint){
  return new BreakString(str).break(hint);
}, 100);

shortDate = function(date){
  return moment(date).format(I18n.t("dates.medium.date_year"));
};

shortDateNoYear = function(date) {
  return moment(date).format(I18n.t("dates.tiny.date_month"));
};

tinyDateYear = function(date) {
  return moment(date).format(I18n.t("dates.tiny.date_year"));
};

// http://stackoverflow.com/questions/196972/convert-string-to-title-case-with-javascript
// TODO: locale support ?
toTitleCase = function toTitleCase(str) {
  return str.replace(/\w\S*/g, function(txt){
    return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
  });
};

longDate = function(dt) {
  if (!dt) return;
  return moment(dt).longDate();
};

// suppress year, if current year
longDateNoYear = function(dt) {
  if (!dt) return;

  if ((new Date()).getFullYear() !== dt.getFullYear()) {
    return moment(dt).format(I18n.t("dates.long_date_with_year"));
  } else {
    return moment(dt).format(I18n.t("dates.long_date_without_year"));
  }
};

updateRelativeAge = function(elems) {
  // jQuery .each
  elems.each(function(){
    var $this = $(this);
    $this.html(relativeAge(new Date($this.data('time')), {format: $this.data('format'), wrapInSpan: false}));
  });
};

autoUpdatingRelativeAge = function(date,options) {
  if (!date) return "";
  if (+date === +new Date(0)) return "";

  options = options || {};
  var format = options.format || "tiny";

  var append = "";

  if(format === 'medium') {
    append = " date";
    if(options.leaveAgo) {
      format = 'medium-with-ago';
    }
    options.wrapInSpan = false;
  }

  var relAge = relativeAge(date, options);

  if (format === 'tiny' && relativeAgeTinyShowsYear(relAge)) {
    append += " with-year";
  }

  if (options.title) {
    append += "' title='" + longDate(date);
  }

  return "<span class='relative-date" + append + "' data-time='" + date.getTime() + "' data-format='" + format +  "'>" + relAge  + "</span>";
};


relativeAgeTiny = function(date){
  var format = "tiny";
  var distance = Math.round((new Date() - date) / 1000);
  var distanceInMinutes = Math.round(distance / 60.0);

  var formatted;
  var t = function(key,opts){
    return I18n.t("dates." + format + "." + key, opts);
  };

  switch(true){

  case(distanceInMinutes < 1):
    formatted = t("less_than_x_minutes", {count: 1});
    break;
  case(distanceInMinutes >= 1 && distanceInMinutes <= 44):
    formatted = t("x_minutes", {count: distanceInMinutes});
    break;
  case(distanceInMinutes >= 45 && distanceInMinutes <= 89):
    formatted = t("about_x_hours", {count: 1});
    break;
  case(distanceInMinutes >= 90 && distanceInMinutes <= 1439):
    formatted = t("about_x_hours", {count: Math.round(distanceInMinutes / 60.0)});
    break;
  case(Discourse.SiteSettings.relative_date_duration === 0 && distanceInMinutes <= 525599):
    formatted = shortDateNoYear(date);
    break;
  case(distanceInMinutes >= 1440 && distanceInMinutes <= 2519):
    formatted = t("x_days", {count: 1});
    break;
  case(distanceInMinutes >= 2520 && distanceInMinutes <= ((Discourse.SiteSettings.relative_date_duration||14) * 1440)):
    formatted = t("x_days", {count: Math.round(distanceInMinutes / 1440.0)});
    break;
  default:
    if(date.getFullYear() === new Date().getFullYear()) {
      formatted = shortDateNoYear(date);
    } else {
      formatted = tinyDateYear(date);
    }
    break;
  }

  return formatted;
};

/*
 * Returns true if the given tiny date string includes the year.
 * Useful for checking if the string isn't so tiny.
 */
relativeAgeTinyShowsYear = function(relativeAgeString) {
  return relativeAgeString.match(/'[\d]{2}$/);
};

relativeAgeMediumSpan = function(distance, leaveAgo) {
  var formatted, distanceInMinutes;

  distanceInMinutes = Math.round(distance / 60.0);

  var t = function(key, opts){
    return I18n.t("dates.medium" + (leaveAgo?"_with_ago":"") + "." + key, opts);
  };

  switch(true){
  case(distanceInMinutes >= 1 && distanceInMinutes <= 55):
    formatted = t("x_minutes", {count: distanceInMinutes});
    break;
  case(distanceInMinutes >= 56 && distanceInMinutes <= 89):
    formatted = t("x_hours", {count: 1});
    break;
  case(distanceInMinutes >= 90 && distanceInMinutes <= 1379):
    formatted = t("x_hours", {count: Math.round(distanceInMinutes / 60.0)});
    break;
  case(distanceInMinutes >= 1380 && distanceInMinutes <= 2159):
    formatted = t("x_days", {count: 1});
    break;
  case(distanceInMinutes >= 2160):
    formatted = t("x_days", {count: Math.round((distanceInMinutes - 720.0) / 1440.0)});
    break;
  }
  return formatted || '&mdash';
};

relativeAgeMedium = function(date, options){
  var displayDate, fiveDaysAgo, oneMinuteAgo, fullReadable, leaveAgo;
  var wrapInSpan = options.wrapInSpan !== false;

  leaveAgo = options.leaveAgo;
  var distance = Math.round((new Date() - date) / 1000);

  if (!date) {
    return "&mdash;";
  }

  fullReadable = longDate(date);
  displayDate = "";
  fiveDaysAgo = 432000;
  oneMinuteAgo = 60;

  if (distance < oneMinuteAgo) {
    displayDate = I18n.t("now");
  } else if (distance > fiveDaysAgo) {
    if ((new Date()).getFullYear() !== date.getFullYear()) {
      displayDate = shortDate(date);
    } else {
      displayDate = shortDateNoYear(date);
    }
  } else {
    displayDate = relativeAgeMediumSpan(distance, leaveAgo);
  }
  if(wrapInSpan) {
    return "<span class='date' title='" + fullReadable + "'>" + displayDate + "</span>";
  } else {
    return displayDate;
  }
};

// mostly lifted from rails with a few amendments
relativeAge = function(date, options) {
  options = options || {};
  var format = options.format || "tiny";

  if(format === "tiny") {
    return relativeAgeTiny(date, options);
  } else if (format === "medium") {
    return relativeAgeMedium(date, options);
  } else if (format === 'medium-with-ago') {
    return relativeAgeMedium(date, _.extend(options, {format: 'medium', leaveAgo: true}));
  }

  return "UNKNOWN FORMAT";
};

var number = function(val) {
  var formattedNumber;

  val = parseInt(val, 10);
  if (isNaN(val)) val = 0;

  if (val > 999999) {
    formattedNumber = I18n.toNumber(val / 1000000, {precision: 1});
    return I18n.t("number.short.millions", {number: formattedNumber});
  }
  if (val > 999) {
    formattedNumber = I18n.toNumber(val / 1000, {precision: 1});
    return I18n.t("number.short.thousands", {number: formattedNumber});
  }
  return val.toString();
};

Discourse.Formatter = {
  longDate: longDate,
  longDateNoYear: longDateNoYear,
  relativeAge: relativeAge,
  autoUpdatingRelativeAge: autoUpdatingRelativeAge,
  updateRelativeAge: updateRelativeAge,
  toTitleCase: toTitleCase,
  shortDate: shortDate,
  breakUp: breakUp,
  cappedMemoize: cappedMemoize,
  number: number
};

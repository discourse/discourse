/* global BreakString:true */

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
function cappedMemoize(fn, max) {
  fn.maxMemoize = max;
  fn.memoizeLength = 0;

  return function() {
    const args = Array.prototype.slice.call(arguments);
    let hash = "";
    let i = args.length;
    let currentArg = null;
    while (i--) {
      currentArg = args[i];
      hash +=
        currentArg === new Object(currentArg)
          ? JSON.stringify(currentArg)
          : currentArg;
      if (!fn.memoize) {
        fn.memoize = {};
      }
    }
    if (hash in fn.memoize) {
      return fn.memoize[hash];
    } else {
      fn.memoizeLength++;
      if (fn.memoizeLength > max) {
        fn.memoizeLength = 0;
        fn.memoize = {};
      }
      const result = fn.apply(this, args);
      fn.memoize[hash] = result;
      return result;
    }
  };
}

const breakUp = cappedMemoize(function(str, hint) {
  return new BreakString(str).break(hint);
}, 100);
export { breakUp };

export function shortDate(date) {
  return moment(date).format(I18n.t("dates.medium.date_year"));
}

function shortDateNoYear(date) {
  return moment(date).format(I18n.t("dates.tiny.date_month"));
}

// Suppress year if it's this year
export function smartShortDate(date, withYear = tinyDateYear) {
  return date.getFullYear() === new Date().getFullYear()
    ? shortDateNoYear(date)
    : withYear(date);
}

export function tinyDateYear(date) {
  return moment(date).format(I18n.t("dates.tiny.date_year"));
}

// http://stackoverflow.com/questions/196972/convert-string-to-title-case-with-javascript
// TODO: locale support ?
export function toTitleCase(str) {
  return str.replace(/\w\S*/g, function(txt) {
    return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
  });
}

export function longDate(dt) {
  if (!dt) return;
  return moment(dt).format(I18n.t("dates.long_with_year"));
}

// suppress year, if current year
export function longDateNoYear(dt) {
  if (!dt) return;

  if (new Date().getFullYear() !== dt.getFullYear()) {
    return moment(dt).format(I18n.t("dates.long_date_with_year"));
  } else {
    return moment(dt).format(I18n.t("dates.long_date_without_year"));
  }
}

export function updateRelativeAge(elems) {
  // jQuery .each
  elems.each(function() {
    const $this = $(this);
    $this.html(
      relativeAge(new Date($this.data("time")), {
        format: $this.data("format"),
        wrapInSpan: false
      })
    );
  });
}

export function autoUpdatingRelativeAge(date, options) {
  if (!date) return "";
  if (+date === +new Date(0)) return "";

  options = options || {};
  let format = options.format || "tiny";

  let append = "";
  if (format === "medium") {
    append = " date";
    if (options.leaveAgo) {
      format = "medium-with-ago";
    }
    options.wrapInSpan = false;
  }

  const relAge = relativeAge(date, options);

  if (format === "tiny" && relativeAgeTinyShowsYear(relAge)) {
    append += " with-year";
  }

  if (options.title) {
    append += "' title='" + longDate(date);
  }

  return (
    "<span class='relative-date" +
    append +
    "' data-time='" +
    date.getTime() +
    "' data-format='" +
    format +
    "'>" +
    relAge +
    "</span>"
  );
}

function wrapAgo(dateStr) {
  return I18n.t("dates.wrap_ago", { date: dateStr });
}

export function durationTiny(distance, ageOpts) {
  if (typeof distance !== "number") {
    return "&mdash;";
  }

  const dividedDistance = Math.round(distance / 60.0);
  const distanceInMinutes = dividedDistance < 1 ? 1 : dividedDistance;

  const t = function(key, opts) {
    const result = I18n.t("dates.tiny." + key, opts);
    return ageOpts && ageOpts.addAgo ? wrapAgo(result) : result;
  };

  let formatted;

  switch (true) {
    case distance <= 59:
      formatted = t("less_than_x_minutes", { count: 1 });
      break;
    case distanceInMinutes >= 0 && distanceInMinutes <= 44:
      formatted = t("x_minutes", { count: distanceInMinutes });
      break;
    case distanceInMinutes >= 45 && distanceInMinutes <= 89:
      formatted = t("about_x_hours", { count: 1 });
      break;
    case distanceInMinutes >= 90 && distanceInMinutes <= 1409:
      formatted = t("about_x_hours", {
        count: Math.round(distanceInMinutes / 60.0)
      });
      break;
    case distanceInMinutes >= 1410 && distanceInMinutes <= 2519:
      formatted = t("x_days", { count: 1 });
      break;
    case distanceInMinutes >= 2520 && distanceInMinutes <= 129599:
      formatted = t("x_days", {
        count: Math.round(distanceInMinutes / 1440.0)
      });
      break;
    case distanceInMinutes >= 129600 && distanceInMinutes <= 525599:
      formatted = t("x_months", {
        count: Math.round(distanceInMinutes / 43200.0)
      });
      break;
    default:
      const numYears = distanceInMinutes / 525600.0;
      const remainder = numYears % 1;
      if (remainder < 0.25) {
        formatted = t("about_x_years", { count: parseInt(numYears) });
      } else if (remainder < 0.75) {
        formatted = t("over_x_years", { count: parseInt(numYears) });
      } else {
        formatted = t("almost_x_years", { count: parseInt(numYears) + 1 });
      }

      break;
  }

  return formatted;
}

function relativeAgeTiny(date, ageOpts) {
  const format = "tiny";
  const distance = Math.round((new Date() - date) / 1000);
  const dividedDistance = Math.round(distance / 60.0);
  const distanceInMinutes = dividedDistance < 1 ? 1 : dividedDistance;

  let formatted;
  const t = function(key, opts) {
    const result = I18n.t("dates." + format + "." + key, opts);
    return ageOpts && ageOpts.addAgo ? wrapAgo(result) : result;
  };

  switch (true) {
    case distanceInMinutes >= 0 && distanceInMinutes <= 44:
      formatted = t("x_minutes", { count: distanceInMinutes });
      break;
    case distanceInMinutes >= 45 && distanceInMinutes <= 89:
      formatted = t("about_x_hours", { count: 1 });
      break;
    case distanceInMinutes >= 90 && distanceInMinutes <= 1409:
      formatted = t("about_x_hours", {
        count: Math.round(distanceInMinutes / 60.0)
      });
      break;
    case Discourse.SiteSettings.relative_date_duration === 0 &&
      distanceInMinutes <= 525599:
      formatted = shortDateNoYear(date);
      break;
    case distanceInMinutes >= 1410 && distanceInMinutes <= 2519:
      formatted = t("x_days", { count: 1 });
      break;
    case distanceInMinutes >= 2520 &&
      distanceInMinutes <=
        (Discourse.SiteSettings.relative_date_duration || 14) * 1440:
      formatted = t("x_days", {
        count: Math.round(distanceInMinutes / 1440.0)
      });
      break;
    default:
      formatted = (ageOpts.defaultFormat || smartShortDate)(date);
      break;
  }

  return formatted;
}

/*
 * Returns true if the given tiny date string includes the year.
 * Useful for checking if the string isn't so tiny.
 */
function relativeAgeTinyShowsYear(relativeAgeString) {
  return relativeAgeString.match(/'[\d]{2}$/);
}

function relativeAgeMediumSpan(distance, leaveAgo) {
  let formatted;
  const distanceInMinutes = Math.round(distance / 60.0);

  const t = function(key, opts) {
    return I18n.t(
      "dates.medium" + (leaveAgo ? "_with_ago" : "") + "." + key,
      opts
    );
  };

  switch (true) {
    case distanceInMinutes >= 1 && distanceInMinutes <= 55:
      formatted = t("x_minutes", { count: distanceInMinutes });
      break;
    case distanceInMinutes >= 56 && distanceInMinutes <= 89:
      formatted = t("x_hours", { count: 1 });
      break;
    case distanceInMinutes >= 90 && distanceInMinutes <= 1409:
      formatted = t("x_hours", { count: Math.round(distanceInMinutes / 60.0) });
      break;
    case distanceInMinutes >= 1410 && distanceInMinutes <= 2159:
      formatted = t("x_days", { count: 1 });
      break;
    case distanceInMinutes >= 2160:
      formatted = t("x_days", {
        count: Math.round((distanceInMinutes - 720.0) / 1440.0)
      });
      break;
  }
  return formatted || "&mdash;";
}

function relativeAgeMedium(date, options) {
  const wrapInSpan = options.wrapInSpan !== false;
  const leaveAgo = options.leaveAgo;
  const distance = Math.round((new Date() - date) / 1000);

  if (!date) {
    return "&mdash;";
  }

  const fullReadable = longDate(date);
  const fiveDaysAgo = 432000;
  const oneMinuteAgo = 60;

  let displayDate = "";
  if (distance < oneMinuteAgo) {
    displayDate = I18n.t("now");
  } else if (distance > fiveDaysAgo) {
    displayDate = smartShortDate(date, shortDate);
  } else {
    displayDate = relativeAgeMediumSpan(distance, leaveAgo);
  }
  if (wrapInSpan) {
    return (
      "<span class='date' title='" +
      fullReadable +
      "'>" +
      displayDate +
      "</span>"
    );
  } else {
    return displayDate;
  }
}

// mostly lifted from rails with a few amendments
export function relativeAge(date, options) {
  options = options || {};
  const format = options.format || "tiny";

  if (format === "tiny") {
    return relativeAgeTiny(date, options);
  } else if (format === "medium") {
    return relativeAgeMedium(date, options);
  } else if (format === "medium-with-ago") {
    return relativeAgeMedium(
      date,
      _.extend(options, { format: "medium", leaveAgo: true })
    );
  }

  return "UNKNOWN FORMAT";
}

export function number(val) {
  let formattedNumber;

  val = Math.round(parseFloat(val));
  if (isNaN(val)) val = 0;

  if (val > 999999) {
    formattedNumber = I18n.toNumber(val / 1000000, { precision: 1 });
    return I18n.t("number.short.millions", { number: formattedNumber });
  } else if (val > 99999) {
    formattedNumber = I18n.toNumber(Math.floor(val / 1000), { precision: 0 });
    return I18n.t("number.short.thousands", { number: formattedNumber });
  } else if (val > 999) {
    formattedNumber = I18n.toNumber(val / 1000, { precision: 1 });
    return I18n.t("number.short.thousands", { number: formattedNumber });
  }
  return val.toString();
}

export function ensureJSON(json) {
  return typeof json === "string" ? JSON.parse(json) : json;
}

export function plainJSON(val) {
  let json = ensureJSON(val);
  let headers = "";
  Object.keys(json).forEach(k => {
    headers += `${k}: ${json[k]}\n`;
  });
  return headers;
}

export function prettyJSON(json) {
  return JSON.stringify(ensureJSON(json), null, 2);
}

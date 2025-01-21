import jQuery from "jquery";
import deprecated from "discourse/lib/deprecated";
import { helperContext, makeArray } from "discourse/lib/helpers";
import I18n, { i18n } from "discourse-i18n";

export function shortDate(date) {
  return moment(date).format(i18n("dates.medium.date_year"));
}

export function shortDateNoYear(date) {
  return moment(date).format(i18n("dates.tiny.date_month"));
}

// Suppress year if it's this year
export function smartShortDate(date, withYear = tinyDateYear) {
  return date.getFullYear() === new Date().getFullYear()
    ? shortDateNoYear(date)
    : withYear(date);
}

export function tinyDateYear(date) {
  return moment(date).format(i18n("dates.tiny.date_year"));
}

// http://stackoverflow.com/questions/196972/convert-string-to-title-case-with-javascript
// TODO: locale support ?
export function toTitleCase(str) {
  return str.replace(/\w\S*/g, function (txt) {
    return txt.charAt(0).toUpperCase() + txt.slice(1).toLowerCase();
  });
}

export function longDate(dt) {
  if (!dt) {
    return;
  }
  return moment(dt).format(i18n("dates.long_with_year"));
}

// suppress year, if current year
export function longDateNoYear(dt) {
  if (!dt) {
    return;
  }

  if (new Date().getFullYear() !== dt.getFullYear()) {
    return moment(dt).format(i18n("dates.long_date_with_year"));
  } else {
    return moment(dt).format(i18n("dates.long_date_without_year"));
  }
}

export function updateRelativeAge(elems) {
  if (elems instanceof jQuery) {
    elems = elems.toArray();
    deprecated("updateRelativeAge now expects a DOM NodeList", {
      since: "2.8.0.beta7",
      dropFrom: "2.9.0.beta1",
      id: "discourse.formatter.update-relative-age-node-list",
    });
  }

  if (!NodeList.prototype.isPrototypeOf(elems)) {
    elems = makeArray(elems);
  }

  elems.forEach((elem) => {
    elem.innerHTML = relativeAge(new Date(parseInt(elem.dataset.time, 10)), {
      format: elem.dataset.format,
      wrapInSpan: false,
    });
  });
}

export function autoUpdatingRelativeAge(date, options) {
  if (!date) {
    return "";
  }
  if (+date === +new Date(0)) {
    return "";
  }

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

  if (options.customTitle) {
    append += "' title='" + options.customTitle;
  } else if (options.title) {
    append += "' title='" + longDate(date);
  }

  let prefix = "";
  if (options.prefix) {
    prefix = options.prefix + " ";
  }

  return (
    "<span class='relative-date" +
    append +
    "' data-time='" +
    date.getTime() +
    "' data-format='" +
    format +
    "'>" +
    prefix +
    relAge +
    "</span>"
  );
}

export function until(untilDate, timezone, locale) {
  const untilMoment = moment.tz(untilDate, timezone);
  const now = moment.tz(timezone);

  let untilFormatted;
  if (now.isSame(untilMoment, "day")) {
    const localeData = moment.localeData(locale);
    untilFormatted = untilMoment.format(localeData.longDateFormat("LT"));
  } else {
    untilFormatted = untilMoment.format(i18n("dates.long_no_year_no_time"));
  }

  return `${i18n("until")} ${untilFormatted}`;
}

function wrapAgo(dateStr) {
  return i18n("dates.wrap_ago", { date: dateStr });
}

function wrapOn(dateStr) {
  return i18n("dates.wrap_on", { date: dateStr });
}

export function duration(distance, ageOpts) {
  if (typeof distance !== "number") {
    return "&mdash;";
  }

  const dividedDistance = Math.round(distance / 60.0);
  const distanceInMinutes = dividedDistance < 1 ? 1 : dividedDistance;

  const t = function (key, opts) {
    const format = (ageOpts && ageOpts.format) || "tiny";
    const result = i18n("dates." + format + "." + key, opts);
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
        count: Math.round(distanceInMinutes / 60.0),
      });
      break;
    case distanceInMinutes >= 1410 && distanceInMinutes <= 2519:
      formatted = t("x_days", { count: 1 });
      break;
    case distanceInMinutes >= 2520 && distanceInMinutes <= 129599:
      formatted = t("x_days", {
        count: Math.round(distanceInMinutes / 1440.0),
      });
      break;
    case distanceInMinutes >= 129600 && distanceInMinutes <= 525599:
      formatted = t("x_months", {
        count: Math.round(distanceInMinutes / 43200.0),
      });
      break;
    default:
      const numYears = distanceInMinutes / 525600.0;
      const remainder = numYears % 1;
      if (remainder < 0.25) {
        formatted = t("about_x_years", { count: Math.floor(numYears) });
      } else if (remainder < 0.75) {
        formatted = t("over_x_years", { count: Math.floor(numYears) });
      } else {
        formatted = t("almost_x_years", { count: Math.floor(numYears) + 1 });
      }

      break;
  }

  return formatted;
}

export function durationTiny(distance, ageOpts) {
  return duration(distance, { format: "tiny", ...ageOpts });
}

function relativeAgeTiny(date, ageOpts) {
  const format = "tiny";
  let distance = Math.round((new Date() - date) / 1000);
  if (distance < 0) {
    distance = Math.round((date - new Date()) / 1000);
  }
  const dividedDistance = Math.round(distance / 60.0);
  const distanceInMinutes = dividedDistance < 1 ? 1 : dividedDistance;

  let formatted;
  const t = function (key, opts) {
    const result = i18n("dates." + format + "." + key, opts);
    return ageOpts && ageOpts.addAgo ? wrapAgo(result) : result;
  };

  // This file is in lib but it's used as a helper
  let siteSettings = helperContext().siteSettings;

  switch (true) {
    case distanceInMinutes >= 0 && distanceInMinutes <= 44:
      formatted = t("x_minutes", { count: distanceInMinutes });
      break;
    case distanceInMinutes >= 45 && distanceInMinutes <= 89:
      formatted = t("about_x_hours", { count: 1 });
      break;
    case distanceInMinutes >= 90 && distanceInMinutes <= 1409:
      formatted = t("about_x_hours", {
        count: Math.round(distanceInMinutes / 60.0),
      });
      break;
    case siteSettings.relative_date_duration === 0 &&
      distanceInMinutes <= 525599:
      formatted = shortDateNoYear(date);
      break;
    case distanceInMinutes >= 1410 && distanceInMinutes <= 2519:
      formatted = t("x_days", { count: 1 });
      break;
    case distanceInMinutes >= 2520 &&
      distanceInMinutes <= (siteSettings.relative_date_duration || 14) * 1440:
      formatted = t("x_days", {
        count: Math.round(distanceInMinutes / 1440.0),
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

export function relativeAgeMediumSpan(distance, leaveAgo) {
  let formatted;
  const distanceInMinutes = Math.round(distance / 60.0);

  const t = function (key, opts) {
    return i18n(
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
    case distanceInMinutes >= 1410 && distanceInMinutes <= 2519:
      formatted = t("x_days", { count: 1 });
      break;
    case distanceInMinutes >= 2520 && distanceInMinutes <= 129599:
      formatted = t("x_days", {
        count: Math.round((distanceInMinutes - 720.0) / 1440.0),
      });
      break;
    case distanceInMinutes >= 129600 && distanceInMinutes <= 525599:
      formatted = t("x_months", {
        count: Math.round(distanceInMinutes / 43200.0),
      });
      break;
    default:
      formatted = t("x_years", {
        count: Math.round(distanceInMinutes / 525600.0),
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
    displayDate = i18n("now");
  } else if (distance > fiveDaysAgo) {
    displayDate = smartShortDate(date, shortDate);
    if (options.wrapOn) {
      displayDate = wrapOn(displayDate);
    }
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
      Object.assign(options, { format: "medium", leaveAgo: true })
    );
  } else if (format === "medium-with-ago-and-on") {
    return relativeAgeMedium(
      date,
      Object.assign(options, { format: "medium", leaveAgo: true, wrapOn: true })
    );
  }

  return "UNKNOWN FORMAT";
}

export function number(val) {
  let formattedNumber;

  val = Math.round(parseFloat(val));
  if (isNaN(val)) {
    val = 0;
  }

  if (val > 999999) {
    formattedNumber = I18n.toNumber(val / 1000000, { precision: 1 });
    return i18n("number.short.millions", { number: formattedNumber });
  } else if (val > 99999) {
    formattedNumber = I18n.toNumber(Math.floor(val / 1000), { precision: 0 });
    return i18n("number.short.thousands", { number: formattedNumber });
  } else if (val > 999) {
    formattedNumber = I18n.toNumber(val / 1000, { precision: 1 });
    return i18n("number.short.thousands", { number: formattedNumber });
  }
  return val.toString();
}

export function ensureJSON(json) {
  return typeof json === "string" ? JSON.parse(json) : json;
}

export function plainJSON(val) {
  let json = ensureJSON(val);
  let headers = "";
  Object.keys(json).forEach((k) => {
    headers += `${k}: ${json[k]}\n`;
  });
  return headers;
}

export function prettyJSON(json) {
  return JSON.stringify(ensureJSON(json), null, 2);
}

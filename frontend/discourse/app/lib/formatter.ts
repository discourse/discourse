import type { MomentInput } from "moment";
import { helperContext, makeArray } from "discourse/lib/helpers";
import type SiteSettingsService from "discourse/services/site-settings";
import I18n, { i18n } from "discourse-i18n";

/**
 * A date in a form `moment()` accepts: a `Date`, a timestamp, a date string or a
 * moment. It is typed by shape so that the published declarations don't import the
 * moment types: a plugin that infers a moment from them could not name its type.
 */
export type DateInput =
  | Date
  | number
  | string
  | { toDate(): Date }
  | null
  | undefined;

/** Options for `relativeAge`. */
export interface RelativeAgeOptions {
  /**
   * The format: `"tiny"` (the default), `"medium"`, `"medium-with-ago"` or
   * `"medium-with-ago-and-on"`.
   */
  format?: string;

  /** Wraps tiny ages in `"%{date} ago"`. */
  addAgo?: boolean;

  /** Formats tiny ages past the relative range. Defaults to `smartShortDate`. */
  defaultFormat?: (date: Date) => string;

  /** Keeps "ago" in medium ages. */
  leaveAgo?: boolean;

  /** Wraps medium ages older than five days in `"on %{date}"`. */
  wrapOn?: boolean;

  /** Whether medium ages are wrapped in a titled span. Defaults to true. */
  wrapInSpan?: boolean;
}

/** Options for `autoUpdatingRelativeAge`. */
export interface AutoUpdatingRelativeAgeOptions extends RelativeAgeOptions {
  /** The span's title. */
  customTitle?: string;

  /** Titles the span with the long date, unless `customTitle` is set. */
  title?: boolean;

  /** Text placed before the age. */
  prefix?: string;
}

/** Options for `duration`. */
export interface DurationOptions {
  /** The `dates` translation group, such as `"tiny"` (the default) or `"medium"`. */
  format?: string;

  /** Wraps the duration in `"%{date} ago"`. */
  addAgo?: boolean;
}

/** Options for `number`. */
export interface NumberOptions {
  /** Shows larger values as this value followed by "+". */
  maxDisplay?: number;
}

/** The elements `updateRelativeAge` updates. */
export type RelativeAgeElements =
  | NodeListOf<HTMLElement>
  | HTMLElement[]
  | HTMLElement
  | null
  | undefined;

/**
 * TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys, so
 * this types the setting read here. Remove it once the service types its settings.
 */
interface RelativeDateSettings {
  relative_date_duration: number;
}

/**
 * Formats a date with its year, such as "Jan 5, 2023".
 *
 * @param date - The date.
 * @returns The formatted date.
 */
export function shortDate(date: DateInput): string {
  return moment(date as MomentInput).format(i18n("dates.medium.date_year"));
}

/**
 * Formats a date without its year, such as "Jan 5".
 *
 * @param date - The date.
 * @returns The formatted date.
 */
export function shortDateNoYear(date: DateInput): string {
  return moment(date as MomentInput).format(i18n("dates.tiny.date_month"));
}

/**
 * Formats a date, leaving out the year when it is this year.
 *
 * @param date - The date.
 * @param withYear - Formats dates from other years. Defaults to `tinyDateYear`.
 * @returns The formatted date.
 */
export function smartShortDate(
  date: Date,
  withYear: (date: Date) => string = tinyDateYear
): string {
  return date.getFullYear() === new Date().getFullYear()
    ? shortDateNoYear(date)
    : withYear(date);
}

/**
 * Formats a date as its month and year, such as "Jan 2023".
 *
 * @param date - The date.
 * @returns The formatted date.
 */
export function tinyDateYear(date: DateInput): string {
  return moment(date as MomentInput).format(i18n("dates.tiny.date_year"));
}

// http://stackoverflow.com/questions/196972/convert-string-to-title-case-with-javascript
// TODO: locale support ?
/**
 * Capitalizes the first letter of each word and lowercases the rest.
 *
 * @param str - The text.
 * @returns The text in title case.
 */
export function toTitleCase(str: string): string {
  return str.replace(/\w\S*/g, function (txt) {
    return txt.charAt(0).toUpperCase() + txt.slice(1).toLowerCase();
  });
}

/**
 * Formats a date with its year and time, such as "Jan 5, 2023 3:04 pm".
 *
 * @param dt - The date.
 * @returns The formatted date, or `undefined` when there is no date.
 */
export function longDate(dt: DateInput): string | undefined {
  if (!dt) {
    return;
  }
  return moment(dt as MomentInput).format(i18n("dates.long_with_year"));
}

/**
 * Formats a date with its time, leaving out the year when it is this year.
 *
 * @param dt - The date.
 * @returns The formatted date, or `undefined` when there is no date.
 */
export function longDateNoYear(
  dt: Date | null | undefined
): string | undefined {
  if (!dt) {
    return;
  }

  if (new Date().getFullYear() !== dt.getFullYear()) {
    return moment(dt).format(i18n("dates.long_date_with_year"));
  } else {
    return moment(dt).format(i18n("dates.long_date_without_year"));
  }
}

/**
 * Rewrites the relative ages rendered by `autoUpdatingRelativeAge`, from each
 * element's `data-time` and `data-format`.
 *
 * @param elems - The elements to update.
 */
export function updateRelativeAge(elems: RelativeAgeElements) {
  if (!NodeList.prototype.isPrototypeOf(elems as object)) {
    elems = makeArray(elems as HTMLElement | HTMLElement[] | null | undefined);
  }

  // Anything that isn't a `NodeList` is an array by now.
  (elems as NodeListOf<HTMLElement> | HTMLElement[]).forEach((elem) => {
    elem.innerHTML = relativeAge(new Date(parseInt(elem.dataset.time!, 10)), {
      format: elem.dataset.format,
      wrapInSpan: false,
    });
  });
}

/**
 * Renders a relative age in a span that `updateRelativeAge` can refresh.
 *
 * @param date - The date.
 * @param options - The format options.
 * @returns The HTML, or `""` for a missing, invalid or zero date.
 */
export function autoUpdatingRelativeAge(
  date: Date | null | undefined,
  options?: AutoUpdatingRelativeAgeOptions | null
): string {
  if (!date || isNaN(date.getTime())) {
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

/**
 * Formats "Until" and a time, for today, or a date.
 *
 * @param untilDate - The end date.
 * @param timezone - The timezone to show it in.
 * @param locale - The locale of the time format.
 * @returns The formatted text.
 */
export function until(
  untilDate: DateInput,
  timezone: string,
  locale: string
): string {
  const untilMoment = moment.tz(untilDate as MomentInput, timezone);
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

function wrapAgo(dateStr: string): string {
  return i18n("dates.wrap_ago", { date: dateStr });
}

function wrapOn(dateStr: string): string {
  return i18n("dates.wrap_on", { date: dateStr });
}

/**
 * Formats a length of time, such as "5 mins" or "about 2 years".
 *
 * @param distance - The length in seconds. Anything that is not a number
 *   renders as a dash.
 * @param ageOpts - The format options.
 * @returns The formatted duration.
 */
export function duration(
  distance: unknown,
  ageOpts?: DurationOptions | null
): string {
  if (typeof distance !== "number") {
    return "&mdash;";
  }

  const dividedDistance = Math.round(distance / 60.0);
  const distanceInMinutes = dividedDistance < 1 ? 1 : dividedDistance;

  const t = function (key: string, opts: Record<string, unknown>): string {
    const format = ageOpts?.format || "tiny";
    const result = i18n("dates." + format + "." + key, opts);
    return ageOpts?.addAgo ? wrapAgo(result) : result;
  };

  let formatted: string;

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

/**
 * Formats a length of time in the tiny format.
 *
 * @param distance - The length in seconds.
 * @param ageOpts - The format options.
 * @returns The formatted duration.
 */
export function durationTiny(
  distance: unknown,
  ageOpts?: DurationOptions | null
): string {
  return duration(distance, { format: "tiny", ...ageOpts });
}

/**
 * Formats seconds as seconds, or as minutes and seconds from one minute up.
 *
 * @param seconds - The number of seconds.
 * @param options - The format options. `subsecondPrecision` sets the decimal
 *   places shown for values under one second, 0 by default.
 * @returns The formatted time.
 */
export function formatMinutesSeconds(
  seconds: number,
  { subsecondPrecision = 0 }: { subsecondPrecision?: number } = {}
): string {
  if (seconds > 0 && seconds < 1 && subsecondPrecision > 0) {
    const minimumSeconds = 10 ** -subsecondPrecision;
    const lessThanMinimum = seconds < minimumSeconds;
    const displayedSeconds = lessThanMinimum ? minimumSeconds : seconds;
    const formattedSeconds = I18n.toNumber(displayedSeconds, {
      precision: subsecondPrecision,
      strip_insignificant_zeros: true,
    });
    const translationKey = lessThanMinimum
      ? "dates.tiny.less_than_x_seconds.other"
      : "dates.tiny.x_seconds.other";

    return i18n(translationKey, {
      count: formattedSeconds,
    });
  }

  const totalSeconds = Math.floor(seconds);

  if (totalSeconds < 60) {
    return i18n("dates.tiny.x_seconds", { count: totalSeconds });
  }

  const minutes = Math.floor(totalSeconds / 60);
  const remainderSeconds = totalSeconds % 60;

  return i18n("dates.tiny.x_minutes_seconds", {
    minutes,
    seconds: remainderSeconds,
  });
}

function relativeAgeTiny(date: Date, ageOpts: RelativeAgeOptions): string {
  const format = "tiny";
  let distance = Math.round((+new Date() - +date) / 1000);
  if (distance < 0) {
    distance = Math.round((+date - +new Date()) / 1000);
  }
  const dividedDistance = Math.round(distance / 60.0);
  const distanceInMinutes = dividedDistance < 1 ? 1 : dividedDistance;

  let formatted: string;
  const t = function (key: string, opts: Record<string, unknown>): string {
    const result = i18n("dates." + format + "." + key, opts);
    return ageOpts?.addAgo ? wrapAgo(result) : result;
  };

  // This file is in lib but it's used as a helper
  const siteSettings = helperContext().siteSettings as SiteSettingsService &
    RelativeDateSettings;

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
function relativeAgeTinyShowsYear(relativeAgeString: string) {
  return relativeAgeString.match(/'[\d]{2}$/);
}

/**
 * Formats an age in the medium format, such as "2 mins" or "2 mins ago".
 *
 * @param distance - The age in seconds.
 * @param leaveAgo - Whether to keep "ago".
 * @returns The formatted age.
 */
export function relativeAgeMediumSpan(
  distance: number,
  leaveAgo?: boolean
): string {
  let formatted: string;
  const distanceInMinutes = Math.round(distance / 60.0);

  const t = function (key: string, opts: Record<string, unknown>): string {
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
        count: Math.round(distanceInMinutes / 1440.0),
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

function relativeAgeMedium(
  date: Date | null | undefined,
  options: RelativeAgeOptions
): string {
  const wrapInSpan = options.wrapInSpan !== false;
  const leaveAgo = options.leaveAgo;
  const distance = Math.round((+new Date() - +date!) / 1000);

  if (!date) {
    return "&mdash;";
  }

  const fullReadable = longDate(date);
  const fiveDaysAgo = 432000;
  const oneMinuteAgo = 60;

  let displayDate: string;
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
/**
 * Formats how long ago a date was.
 *
 * @param date - The date.
 * @param options - The format options.
 * @returns The formatted age, or `"UNKNOWN FORMAT"` for an unknown format.
 */
export function relativeAge(
  date: Date,
  options?: RelativeAgeOptions | null
): string {
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

/**
 * Formats a number in short form, such as "1.2k" or "3.4M".
 *
 * @param val - The number. Values that do not parse as a number count as 0.
 * @param options - The format options.
 * @returns The formatted number.
 */
export function number(
  val: number | string | object | null | undefined,
  options?: NumberOptions | null
): string {
  options = options || {};
  let formattedNumber;

  // `parseFloat` converts any value to a string first.
  val = Math.round(parseFloat(val as string));
  if (isNaN(val)) {
    val = 0;
  }

  const shouldAppendPlus =
    typeof options?.maxDisplay === "number" &&
    options.maxDisplay > 0 &&
    val > 0 &&
    val > options.maxDisplay;

  if (shouldAppendPlus) {
    // `shouldAppendPlus` checked that `maxDisplay` is a number.
    val = options.maxDisplay as number;
  }

  let output;

  if (val > 999999) {
    formattedNumber = I18n.toNumber(val / 1000000, { precision: 1 });
    output = i18n("number.short.millions", { number: formattedNumber });
  } else if (val > 99999) {
    formattedNumber = I18n.toNumber(Math.floor(val / 1000), { precision: 0 });
    output = i18n("number.short.thousands", { number: formattedNumber });
  } else if (val > 999) {
    formattedNumber = I18n.toNumber(val / 1000, { precision: 1 });
    output = i18n("number.short.thousands", { number: formattedNumber });
  } else {
    output = val.toString();
  }

  if (shouldAppendPlus) {
    output += "+";
  }

  return output;
}

/**
 * Parses JSON text, and passes any other value through.
 *
 * @param json - JSON text or an already parsed value.
 * @returns The parsed value.
 */
export function ensureJSON(json: unknown): unknown {
  return typeof json === "string" ? JSON.parse(json) : json;
}

/**
 * Lists the keys and values of an object, one `key: value` per line.
 *
 * @param val - The object, or its JSON text.
 * @returns The text.
 */
export function plainJSON(val: string | Record<string, unknown>): string {
  const json = ensureJSON(val) as Record<string, unknown>;
  let headers = "";
  Object.keys(json).forEach((k) => {
    headers += `${k}: ${json[k]}\n`;
  });
  return headers;
}

/**
 * Formats JSON with an indent of two spaces.
 *
 * @param json - The value, or its JSON text.
 * @returns The formatted JSON.
 */
export function prettyJSON(json: unknown): string {
  return JSON.stringify(ensureJSON(json), null, 2);
}

/** The application provides moment globally. */
declare const moment: typeof import("moment");

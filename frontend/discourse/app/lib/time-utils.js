import { isPresent } from "@ember/utils";

export const START_OF_DAY_HOUR = 8;
export const LATER_TODAY_CUTOFF_HOUR = 17;
export const LATER_TODAY_MAX_HOUR = 18;
export const MOMENT_SUNDAY = 0;
export const MOMENT_MONDAY = 1;
export const MOMENT_TUESDAY = 2;
export const MOMENT_WEDNESDAY = 3;
export const MOMENT_THURSDAY = 4;
export const MOMENT_FRIDAY = 5;
export const MOMENT_SATURDAY = 6;

export function now(timezone) {
  return moment.tz(timezone);
}

export function startOfDay(momentDate, startOfDayHour = START_OF_DAY_HOUR) {
  return momentDate.hour(startOfDayHour).startOf("hour");
}

export function oneHour(timezone) {
  return now(timezone).add(1, "hours");
}

export function twoHours(timezone) {
  return now(timezone).add(2, "hours");
}

export function tomorrow(timezone) {
  return startOfDay(now(timezone).add(1, "day"));
}

export function thisWeekend(timezone) {
  return startOfDay(now(timezone).day(MOMENT_SATURDAY));
}

export function laterToday(timezone) {
  let later = now(timezone).add(3, "hours");
  if (later.hour() >= LATER_TODAY_MAX_HOUR) {
    return later.hour(LATER_TODAY_MAX_HOUR).startOf("hour");
  }
  return later.minutes() < 30
    ? later.startOf("hour")
    : later.add(30, "minutes").startOf("hour");
}

export function twoDays(timezone) {
  return startOfDay(now(timezone).add(2, "days"));
}

export function inNDays(timezone, num) {
  return startOfDay(now(timezone).add(num, "days"));
}

export function laterThisWeek(timezone) {
  return twoDays(timezone);
}

export function nextMonth(timezone) {
  return startOfDay(now(timezone).add(1, "month").startOf("month"));
}

export function twoWeeks(timezone) {
  return startOfDay(now(timezone).add(2, "weeks").day(MOMENT_MONDAY));
}

export function twoMonths(timezone) {
  return startOfDay(now(timezone).add(2, "months").startOf("month"));
}

export function threeMonths(timezone) {
  return startOfDay(now(timezone).add(3, "months").startOf("month"));
}

export function fourMonths(timezone) {
  return startOfDay(now(timezone).add(4, "months").startOf("month"));
}

export function sixMonths(timezone) {
  return startOfDay(now(timezone).add(6, "months").startOf("month"));
}

export function oneYear(timezone) {
  return startOfDay(now(timezone).add(1, "years").startOf("month"));
}

export function thousandYears(timezone) {
  return startOfDay(now(timezone).add(1000, "years").startOf("month"));
}

export function nextBusinessWeekStart(timezone) {
  return startOfDay(now(timezone).add(7, "days")).day(MOMENT_MONDAY);
}

export function parseCustomDatetime(
  date,
  time,
  currentTimezone,
  parseTimezone = null
) {
  // If we are called without a valid date use today
  date = date || new Date().toISOString().split("T")[0];

  let dateTime = isPresent(time) ? `${date} ${time}` : date;
  parseTimezone = parseTimezone || currentTimezone;

  let parsed = moment.tz(dateTime, parseTimezone);

  if (parseTimezone !== currentTimezone) {
    parsed = parsed.tz(currentTimezone);
  }

  return parsed;
}

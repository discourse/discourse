import LocalDateBuilder from "./local-date-builder";

/**
 * @param {string} date - Date in YYYY-MM-DD format
 * @param {string} [time] - Time in HH:mm:ss format
 * @param {string} [timezone] - Timezone string (defaults to local timezone)
 * @param {Object} [options] - Additional options
 * @param {string} [options.format] - Custom date format (moment.js format string)
 * @param {string} [options.recurring] - Recurring pattern (e.g., "1.days", "1.weeks")
 * @param {string} [options.countdown] - Whether to show countdown
 * @param {string} [options.displayedTimezone] - Timezone to display in
 * @param {string[]} [options.timezones] - Additional timezones for tooltip
 * @returns {{ formatted: string, pastEvent: boolean }}
 */
export default function formatLocalDate(date, time, timezone, options = {}) {
  const localTimezone = moment.tz.guess();
  const builderOptions = {
    ...options,
    date,
    time,
    timezone: timezone || localTimezone,
    calendar: !options.format, // Use calendar mode only if no custom format specified
  };
  const builder = new LocalDateBuilder(builderOptions, localTimezone);
  const { formatted, pastEvent } = builder.build();
  return { formatted, pastEvent };
}

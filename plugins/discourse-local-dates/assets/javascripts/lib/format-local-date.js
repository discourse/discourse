import LocalDateBuilder from "./local-date-builder";

/**
 * @param {string} date - Date in YYYY-MM-DD format
 * @param {string} [time] - Time in HH:mm:ss format
 * @param {string} [timezone] - Timezone string (defaults to local timezone)
 * @returns {{ formatted: string, pastEvent: boolean }}
 */
export default function formatLocalDate(date, time, timezone) {
  const localTimezone = moment.tz.guess();
  const builder = new LocalDateBuilder(
    { date, time, timezone: timezone || localTimezone, calendar: true },
    localTimezone
  );
  const { formatted, pastEvent } = builder.build();
  return { formatted, pastEvent };
}

import generateDateMarkup from "./local-date-markup-generator";

/**
 * Generates BBCode markup for the current date/time.
 * @param {string} [userTimezone] - User's timezone (defaults to browser guess)
 * @returns {string} BBCode markup
 */
export default function generateCurrentDateMarkup(userTimezone) {
  return generateDateMarkup(
    {
      date: moment().format("YYYY-MM-DD"),
      time: moment().format("HH:mm:ss"),
    },
    { timezone: userTimezone || moment.tz.guess() },
    false
  );
}

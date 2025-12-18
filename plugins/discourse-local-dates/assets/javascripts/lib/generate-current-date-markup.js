/**
 * Generates BBCode markup for the current date/time.
 * @param {string} [userTimezone] - User's timezone (defaults to browser guess)
 * @returns {string} BBCode markup
 */
export default function generateCurrentDateMarkup(userTimezone) {
  const timezone = userTimezone || moment.tz.guess();
  const date = moment().format("YYYY-MM-DD");
  const time = moment().format("HH:mm:ss");
  return `[date=${date} time=${time} timezone="${timezone}"]`;
}

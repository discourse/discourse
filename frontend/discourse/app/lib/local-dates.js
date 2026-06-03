import { optionalRequire } from "./utilities";

export function applyLocalDates(dates, siteSettings, profileTimezone) {
  if (!siteSettings.discourse_local_dates_enabled) {
    return;
  }

  const _applyLocalDates = optionalRequire(
    "discourse/plugins/discourse-local-dates/initializers/discourse-local-dates",
    "applyLocalDates"
  );

  _applyLocalDates(dates, siteSettings, profileTimezone);
}

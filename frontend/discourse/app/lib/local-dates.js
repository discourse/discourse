import { optionalRequire } from "./utilities";

const _applyLocalDates = optionalRequire(
  "discourse/plugins/discourse-local-dates/initializers/discourse-local-dates",
  "applyLocalDates"
);

export function applyLocalDates(dates, siteSettings, timezone) {
  if (!siteSettings.discourse_local_dates_enabled) {
    return;
  }

  _applyLocalDates(dates, siteSettings, timezone);
}

export function applyLocalDates(dates, siteSettings) {
  if (!siteSettings.discourse_local_dates_enabled) {
    return;
  }

  const _applyLocalDates = requirejs(
    "discourse/plugins/discourse-local-dates/initializers/discourse-local-dates"
  ).applyLocalDates;

  _applyLocalDates(dates, siteSettings);
}

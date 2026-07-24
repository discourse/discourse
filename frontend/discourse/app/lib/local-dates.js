import { applyBehaviorTransformer } from "discourse/lib/transformer";

export function applyLocalDates(dates, siteSettings, timezone) {
  if (!siteSettings.discourse_local_dates_enabled) {
    return;
  }

  applyBehaviorTransformer("apply-local-dates", () => {}, {
    dates,
    siteSettings,
    timezone,
  });
}

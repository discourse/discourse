import I18n, { i18n } from "discourse-i18n";

export function getCurrentBcp47Locale() {
  return I18n.currentLocale().replace("_", "-").toLowerCase();
}

export function getCalendarButtonsText() {
  return {
    today: i18n("discourse_events.toolbar_button.today"),
    month: i18n("discourse_events.toolbar_button.month"),
    week: i18n("discourse_events.toolbar_button.week"),
    day: i18n("discourse_events.toolbar_button.day"),
    list: i18n("discourse_events.toolbar_button.year"),
  };
}

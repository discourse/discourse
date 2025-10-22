import { i18n } from "discourse-i18n";

export function formattedReminderTime(reminderAt, timezone) {
  let reminderAtDate = moment.tz(reminderAt, timezone);
  let formatted = reminderAtDate.format(i18n("dates.time"));
  let now = moment.tz(timezone);
  let tomorrow = moment(now).add(1, "day");

  if (reminderAtDate.isSame(tomorrow, "date")) {
    return i18n("bookmarks.reminders.tomorrow_with_time", {
      time: formatted,
    });
  } else if (reminderAtDate.isSame(now, "date")) {
    return i18n("bookmarks.reminders.today_with_time", { time: formatted });
  }
  return i18n("bookmarks.reminders.at_time", {
    date_time: reminderAtDate.format(i18n("dates.long_with_year")),
  });
}

import I18n from "I18n";
export function formattedReminderTime(reminderAt, timezone) {
  let reminderAtDate = moment.tz(reminderAt, timezone);
  let formatted = reminderAtDate.format(I18n.t("dates.time"));
  let now = moment.tz(timezone);
  let tomorrow = moment(now).add(1, "day");

  if (reminderAtDate.isSame(tomorrow, "date")) {
    return I18n.t("bookmarks.reminders.tomorrow_with_time", {
      time: formatted,
    });
  } else if (reminderAtDate.isSame(now, "date")) {
    return I18n.t("bookmarks.reminders.today_with_time", { time: formatted });
  }
  return I18n.t("bookmarks.reminders.at_time", {
    date_time: reminderAtDate.format(I18n.t("dates.long_with_year")),
  });
}

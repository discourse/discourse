import I18n from "I18n";
export function formattedReminderTime(reminderAt, timezone) {
  let reminderAtDate = moment.tz(reminderAt, timezone);
  let formatted = reminderAtDate.format(I18n.t("dates.time"));
  let now = moment.tz(timezone);
  let tomorrow = moment(now).add(1, "day");

  if (reminderAtDate.isSame(tomorrow, "date")) {
    return I18n.t("bookmarks.reminders.tomorrow_with_time", {
      time: formatted
    });
  } else if (reminderAtDate.isSame(now, "date")) {
    return I18n.t("bookmarks.reminders.today_with_time", { time: formatted });
  }
  return I18n.t("bookmarks.reminders.at_time", {
    date_time: reminderAtDate.format(I18n.t("dates.long_with_year"))
  });
}

export const REMINDER_TYPES = {
  LATER_TODAY: "later_today",
  NEXT_BUSINESS_DAY: "next_business_day",
  TOMORROW: "tomorrow",
  NEXT_WEEK: "next_week",
  NEXT_MONTH: "next_month",
  CUSTOM: "custom",
  LAST_CUSTOM: "last_custom",
  NONE: "none",
  START_OF_NEXT_BUSINESS_WEEK: "start_of_next_business_week",
  LATER_THIS_WEEK: "later_this_week"
};

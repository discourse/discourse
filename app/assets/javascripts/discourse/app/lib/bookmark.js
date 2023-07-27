import I18n from "I18n";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/time-shortcut";
import { tracked } from "@glimmer/tracking";

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

export class BookmarkFormData {
  @tracked selectedDatetime;
  @tracked selectedReminderType = TIME_SHORTCUT_TYPES.NONE;
  @tracked id;
  @tracked reminderAt;
  @tracked autoDeletePreference;
  @tracked name;
  @tracked bookmarkableId;
  @tracked bookmarkableType;

  constructor(bookmark) {
    this.id = bookmark.id;
    this.reminderAt = bookmark.reminder_at;
    this.name = bookmark.name;
    this.bookmarkableId = bookmark.bookmarkable_id;
    this.bookmarkableType = bookmark.bookmarkable_type;
    this.autoDeletePreference =
      bookmark.auto_delete_preference ?? AUTO_DELETE_PREFERENCES.CLEAR_REMINDER;
  }

  get reminderAtISO() {
    if (!this.selectedReminderType || !this.selectedDatetime) {
      return;
    }

    return this.selectedDatetime.toISOString();
  }

  get saveData() {
    return {
      reminder_at: this.reminderAtISO,
      name: this.name,
      id: this.id,
      auto_delete_preference: this.autoDeletePreference,
      bookmarkable_id: this.bookmarkableId,
      bookmarkable_type: this.bookmarkableType,
    };
  }
}

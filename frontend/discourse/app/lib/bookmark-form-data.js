import { tracked } from "@glimmer/tracking";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/time-shortcut";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";

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
    if (this.selectedReminderType === TIME_SHORTCUT_TYPES.NONE) {
      return null;
    }

    if (!this.selectedReminderType || !this.selectedDatetime) {
      if (this.reminderAt) {
        return this.reminderAt.toISOString();
      } else {
        return null;
      }
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

  formattedReminder(timezone) {
    return formattedReminderTime(this.reminderAt, timezone);
  }
}

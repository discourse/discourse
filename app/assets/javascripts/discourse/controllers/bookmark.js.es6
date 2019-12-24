import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { reads } from "@ember/object/computed";

const START_OF_DAY_HOUR = 8;
const REMINDER_TYPES = {
  AT_DESKTOP: "at_desktop",
  LATER_TODAY: "later_today",
  NEXT_BUSINESS_DAY: "next_business_day",
  TOMORROW: "tomorrow",
  NEXT_WEEK: "next_week",
  NEXT_MONTH: "next_month",
  CUSTOM: "custom"
};

export default Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,
  name: null,
  selectedReminderType: null,
  closeWithoutSaving: false,
  isSavingBookmarkManually: false,
  onCloseWithoutSaving: null,

  onShow() {
    this.setProperties({
      errorMessage: null,
      name: null,
      selectedReminderType: null,
      closeWithoutSaving: false,
      isSavingBookmarkManually: false
    });
  },

  // we always want to save the bookmark unless the user specifically
  // clicks the save or cancel button to mimic browser behaviour
  onClose() {
    if (!this.closeWithoutSaving && !this.isSavingBookmarkManually) {
      this.saveBookmark();
    }
    if (this.onCloseWithoutSaving && this.closeWithoutSaving) {
      this.onCloseWithoutSaving();
    }
  },

  usingMobileDevice: reads("site.mobileView"),

  @discourseComputed()
  reminderTypes: () => {
    return REMINDER_TYPES;
  },

  @discourseComputed()
  showLaterToday() {
    return !this.laterToday().isSame(this.tomorrow(), "date");
  },

  @discourseComputed()
  laterTodayFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.later_today", {
        date: this.laterToday().format(I18n.t("dates.time"))
      })
    );
  },

  @discourseComputed()
  tomorrowFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.tomorrow", {
        date: this.tomorrow().format(I18n.t("dates.time_short_day"))
      })
    );
  },

  @discourseComputed()
  nextBusinessDayFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.next_business_day", {
        date: this.nextBusinessDay().format(I18n.t("dates.time_short_day"))
      })
    );
  },

  @discourseComputed()
  nextWeekFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.next_week", {
        date: this.nextWeek().format(I18n.t("dates.long_no_year"))
      })
    );
  },

  @discourseComputed()
  nextMonthFormatted() {
    return htmlSafe(
      I18n.t("bookmarks.reminders.next_month", {
        date: this.nextMonth().format(I18n.t("dates.long_no_year"))
      })
    );
  },

  @discourseComputed()
  userHasTimezoneSet() {
    return !_.isEmpty(this.userTimezone());
  },

  saveBookmark() {
    const reminderAt = this.reminderAt();
    const reminderAtISO = reminderAt ? reminderAt.toISOString() : null;
    const data = {
      reminder_type: this.selectedReminderType,
      reminder_at: reminderAtISO,
      name: this.name,
      post_id: this.model.postId
    };

    return ajax("/bookmarks", { type: "POST", data }).then(() => {
      if (this.afterSave) {
        this.afterSave(reminderAtISO);
      }
    });
  },

  reminderAt() {
    if (!this.selectedReminderType) {
      return;
    }

    switch (this.selectedReminderType) {
      case REMINDER_TYPES.AT_DESKTOP:
        // TODO: Implement at desktop bookmark reminder functionality
        return "";
      case REMINDER_TYPES.LATER_TODAY:
        return this.laterToday();
      case REMINDER_TYPES.NEXT_BUSINESS_DAY:
        return this.nextBusinessDay();
      case REMINDER_TYPES.TOMORROW:
        return this.tomorrow();
      case REMINDER_TYPES.NEXT_WEEK:
        return this.nextWeek();
      case REMINDER_TYPES.NEXT_MONTH:
        return this.nextMonth();
      case REMINDER_TYPES.CUSTOM:
        // TODO: Implement custom bookmark reminder times
        return "";
    }
  },

  nextWeek() {
    return this.startOfDay(this.now().add(7, "days"));
  },

  nextMonth() {
    return this.startOfDay(this.now().add(1, "month"));
  },

  nextBusinessDay() {
    const currentDay = this.now().isoWeekday(); // 1=Mon, 7=Sun
    let next = null;

    // friday
    if (currentDay === 5) {
      next = this.now().add(3, "days");
      // saturday
    } else if (currentDay === 6) {
      next = this.now().add(2, "days");
    } else {
      next = this.now().add(1, "day");
    }

    return this.startOfDay(next);
  },

  tomorrow() {
    return this.startOfDay(this.now().add(1, "day"));
  },

  startOfDay(momentDate) {
    return momentDate.hour(START_OF_DAY_HOUR).startOf("hour");
  },

  userTimezone() {
    return this.currentUser.timezone;
  },

  now() {
    return moment.tz(this.userTimezone());
  },

  laterToday() {
    let later = this.now().add(3, "hours");
    return later.minutes() < 30
      ? later.minutes(30)
      : later.add(30, "minutes").startOf("hour");
  },

  actions: {
    saveAndClose() {
      this.isSavingBookmarkManually = true;
      this.saveBookmark()
        .then(() => this.send("closeModal"))
        .catch(e => {
          this.isSavingBookmarkManually = false;
          popupAjaxError(e);
        });
    },

    closeWithoutSavingBookmark() {
      this.closeWithoutSaving = true;
      this.send("closeModal");
    },

    selectReminderType(type) {
      this.set("selectedReminderType", type);
    }
  }
});

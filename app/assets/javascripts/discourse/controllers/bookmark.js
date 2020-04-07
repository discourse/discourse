import { and } from "@ember/object/computed";
import { next } from "@ember/runloop";
import Controller from "@ember/controller";
import { Promise } from "rsvp";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";

// global shortcuts that interfere with these modal shortcuts, they are rebound when the
// modal is closed
//
// c createTopic
// r replyToPost
// l toggle like
// d deletePost
// t replyAsNewTopic
const GLOBAL_SHORTCUTS_TO_PAUSE = ["c", "r", "l", "d", "t"];
const START_OF_DAY_HOUR = 8;
const LATER_TODAY_CUTOFF_HOUR = 17;
const REMINDER_TYPES = {
  AT_DESKTOP: "at_desktop",
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

const BOOKMARK_BINDINGS = {
  enter: { handler: "saveAndClose" },
  "l t": { handler: "selectReminderType", args: [REMINDER_TYPES.LATER_TODAY] },
  "l w": {
    handler: "selectReminderType",
    args: [REMINDER_TYPES.LATER_THIS_WEEK]
  },
  "n b d": {
    handler: "selectReminderType",
    args: [REMINDER_TYPES.NEXT_BUSINESS_DAY]
  },
  "n d": { handler: "selectReminderType", args: [REMINDER_TYPES.TOMORROW] },
  "n w": { handler: "selectReminderType", args: [REMINDER_TYPES.NEXT_WEEK] },
  "n b w": {
    handler: "selectReminderType",
    args: [REMINDER_TYPES.START_OF_NEXT_BUSINESS_WEEK]
  },
  "n m": { handler: "selectReminderType", args: [REMINDER_TYPES.NEXT_MONTH] },
  "c r": { handler: "selectReminderType", args: [REMINDER_TYPES.CUSTOM] },
  "n r": { handler: "selectReminderType", args: [REMINDER_TYPES.NONE] }
};

export default Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,
  name: null,
  selectedReminderType: null,
  closeWithoutSaving: false,
  isSavingBookmarkManually: false,
  onCloseWithoutSaving: null,
  customReminderDate: null,
  customReminderTime: null,
  lastCustomReminderDate: null,
  lastCustomReminderTime: null,
  mouseTrap: null,
  userTimezone: null,

  onShow() {
    this.setProperties({
      errorMessage: null,
      name: null,
      selectedReminderType: REMINDER_TYPES.NONE,
      closeWithoutSaving: false,
      isSavingBookmarkManually: false,
      customReminderDate: null,
      customReminderTime: null,
      lastCustomReminderDate: null,
      lastCustomReminderTime: null,
      userTimezone: this.currentUser.resolvedTimezone()
    });

    this.bindKeyboardShortcuts();
    this.loadLastUsedCustomReminderDatetime();

    // make sure the input is cleared, otherwise the keyboard shortcut to toggle
    // bookmark for post ends up in the input
    next(() => this.set("name", null));
  },

  loadLastUsedCustomReminderDatetime() {
    let lastTime = localStorage.lastCustomBookmarkReminderTime;
    let lastDate = localStorage.lastCustomBookmarkReminderDate;

    if (lastTime && lastDate) {
      let parsed = this.parseCustomDateTime(lastDate, lastTime);

      if (parsed < this.now()) {
        return;
      }

      this.setProperties({
        lastCustomReminderDate: lastDate,
        lastCustomReminderTime: lastTime,
        parsedLastCustomReminderDatetime: parsed
      });
    }
  },

  bindKeyboardShortcuts() {
    KeyboardShortcuts.pause(GLOBAL_SHORTCUTS_TO_PAUSE);
    KeyboardShortcuts.addBindings(BOOKMARK_BINDINGS, binding => {
      if (binding.args) {
        return this.send(binding.handler, ...binding.args);
      }
      this.send(binding.handler);
    });
  },

  unbindKeyboardShortcuts() {
    KeyboardShortcuts.unbind(BOOKMARK_BINDINGS, this.mouseTrap);
  },

  restoreGlobalShortcuts() {
    KeyboardShortcuts.unpause(...GLOBAL_SHORTCUTS_TO_PAUSE);
  },

  // we always want to save the bookmark unless the user specifically
  // clicks the save or cancel button to mimic browser behaviour
  onClose() {
    this.unbindKeyboardShortcuts();
    this.restoreGlobalShortcuts();
    if (!this.closeWithoutSaving && !this.isSavingBookmarkManually) {
      this.saveBookmark().catch(e => this.handleSaveError(e));
    }
    if (this.onCloseWithoutSaving && this.closeWithoutSaving) {
      this.onCloseWithoutSaving();
    }
  },

  showBookmarkReminderControls: true,

  @discourseComputed()
  showAtDesktop() {
    return (
      this.siteSettings.enable_bookmark_at_desktop_reminders &&
      this.site.mobileView
    );
  },

  @discourseComputed("selectedReminderType")
  customDateTimeSelected(selectedReminderType) {
    return selectedReminderType === REMINDER_TYPES.CUSTOM;
  },

  @discourseComputed()
  reminderTypes: () => {
    return REMINDER_TYPES;
  },

  showLastCustom: and("lastCustomReminderTime", "lastCustomReminderDate"),

  @discourseComputed()
  showLaterToday() {
    let later = this.laterToday();
    return (
      !later.isSame(this.tomorrow(), "date") &&
      later.hour() <= LATER_TODAY_CUTOFF_HOUR
    );
  },

  @discourseComputed()
  showLaterThisWeek() {
    return this.now().day() < 4; // 4 is Thursday
  },

  @discourseComputed("parsedLastCustomReminderDatetime")
  lastCustomFormatted(parsedLastCustomReminderDatetime) {
    return parsedLastCustomReminderDatetime.format(
      I18n.t("dates.long_no_year")
    );
  },

  @discourseComputed()
  startNextBusinessWeekFormatted() {
    return this.nextWeek()
      .day("Monday")
      .format(I18n.t("dates.long_no_year"));
  },

  @discourseComputed()
  laterTodayFormatted() {
    return this.laterToday().format(I18n.t("dates.time"));
  },

  @discourseComputed()
  tomorrowFormatted() {
    return this.tomorrow().format(I18n.t("dates.time_short_day"));
  },

  @discourseComputed()
  nextWeekFormatted() {
    return this.nextWeek().format(I18n.t("dates.long_no_year"));
  },

  @discourseComputed()
  laterThisWeekFormatted() {
    return this.laterThisWeek().format(I18n.t("dates.time_short_day"));
  },

  @discourseComputed()
  nextMonthFormatted() {
    return this.nextMonth().format(I18n.t("dates.long_no_year"));
  },

  @discourseComputed()
  basePath() {
    return Discourse.BaseUri;
  },

  @discourseComputed("userTimezone")
  userHasTimezoneSet(userTimezone) {
    return !_.isEmpty(userTimezone);
  },

  saveBookmark() {
    const reminderAt = this.reminderAt();
    const reminderAtISO = reminderAt ? reminderAt.toISOString() : null;

    if (this.selectedReminderType === REMINDER_TYPES.CUSTOM) {
      if (!reminderAt) {
        return Promise.reject(I18n.t("bookmarks.invalid_custom_datetime"));
      }

      localStorage.lastCustomBookmarkReminderTime = this.customReminderTime;
      localStorage.lastCustomBookmarkReminderDate = this.customReminderDate;
    }

    let reminderType;
    if (this.selectedReminderType === REMINDER_TYPES.NONE) {
      reminderType = null;
    } else if (this.selectedReminderType === REMINDER_TYPES.LAST_CUSTOM) {
      reminderType = REMINDER_TYPES.CUSTOM;
    } else {
      reminderType = this.selectedReminderType;
    }

    const data = {
      reminder_type: reminderType,
      reminder_at: reminderAtISO,
      name: this.name,
      post_id: this.model.postId
    };

    return ajax("/bookmarks", { type: "POST", data }).then(() => {
      if (this.afterSave) {
        this.afterSave(reminderAtISO, this.selectedReminderType);
      }
    });
  },

  parseCustomDateTime(date, time) {
    return moment.tz(date + " " + time, this.userTimezone);
  },

  reminderAt() {
    if (!this.selectedReminderType) {
      return;
    }

    switch (this.selectedReminderType) {
      case REMINDER_TYPES.AT_DESKTOP:
        return null;
      case REMINDER_TYPES.LATER_TODAY:
        return this.laterToday();
      case REMINDER_TYPES.NEXT_BUSINESS_DAY:
        return this.nextBusinessDay();
      case REMINDER_TYPES.TOMORROW:
        return this.tomorrow();
      case REMINDER_TYPES.NEXT_WEEK:
        return this.nextWeek();
      case REMINDER_TYPES.START_OF_NEXT_BUSINESS_WEEK:
        return this.nextWeek().day("Monday");
      case REMINDER_TYPES.LATER_THIS_WEEK:
        return this.laterThisWeek();
      case REMINDER_TYPES.NEXT_MONTH:
        return this.nextMonth();
      case REMINDER_TYPES.CUSTOM:
        this.set(
          "customReminderTime",
          this.customReminderTime || `0${START_OF_DAY_HOUR}:00`
        );
        const customDateTime = this.parseCustomDateTime(
          this.customReminderDate,
          this.customReminderTime
        );
        if (!customDateTime.isValid()) {
          this.setProperties({
            customReminderTime: null,
            customReminderDate: null
          });
          return;
        }
        return customDateTime;
      case REMINDER_TYPES.LAST_CUSTOM:
        return this.parsedLastCustomReminderDatetime;
    }
  },

  nextWeek() {
    return this.startOfDay(this.now().add(7, "days"));
  },

  nextMonth() {
    return this.startOfDay(this.now().add(1, "month"));
  },

  tomorrow() {
    return this.startOfDay(this.now().add(1, "day"));
  },

  startOfDay(momentDate) {
    return momentDate.hour(START_OF_DAY_HOUR).startOf("hour");
  },

  now() {
    return moment.tz(this.userTimezone);
  },

  laterToday() {
    let later = this.now().add(3, "hours");
    return later.minutes() < 30
      ? later.minutes(30)
      : later.add(30, "minutes").startOf("hour");
  },

  laterThisWeek() {
    if (!this.showLaterThisWeek) {
      return;
    }
    return this.startOfDay(this.now().add(2, "days"));
  },

  handleSaveError(e) {
    this.isSavingBookmarkManually = false;
    if (typeof e === "string") {
      bootbox.alert(e);
    } else {
      popupAjaxError(e);
    }
  },

  actions: {
    saveAndClose() {
      if (this.saving) {
        return;
      }

      this.saving = true;
      this.isSavingBookmarkManually = true;
      this.saveBookmark()
        .then(() => this.send("closeModal"))
        .catch(e => this.handleSaveError(e))
        .finally(() => (this.saving = false));
    },

    closeWithoutSavingBookmark() {
      this.closeWithoutSaving = true;
      this.send("closeModal");
    },

    selectReminderType(type) {
      if (type === REMINDER_TYPES.LATER_TODAY && !this.showLaterToday) {
        return;
      }
      this.set("selectedReminderType", type);
    }
  }
});

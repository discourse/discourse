import { and } from "@ember/object/computed";
import { isPresent } from "@ember/utils";
import Controller from "@ember/controller";
import { Promise } from "rsvp";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import { formattedReminderTime, REMINDER_TYPES } from "discourse/lib/bookmark";

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
const LATER_TODAY_MAX_HOUR = 18;

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
  "n r": { handler: "selectReminderType", args: [REMINDER_TYPES.NONE] },
  "d d": { handler: "delete" }
};

export default Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,
  selectedReminderType: null,
  _closeWithoutSaving: false,
  _savingBookmarkManually: false,
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
      selectedReminderType: REMINDER_TYPES.NONE,
      _closeWithoutSaving: false,
      _savingBookmarkManually: false,
      customReminderDate: null,
      customReminderTime: this._defaultCustomReminderTime(),
      lastCustomReminderDate: null,
      lastCustomReminderTime: null,
      userTimezone: this.currentUser.resolvedTimezone()
    });

    this._bindKeyboardShortcuts();
    this._loadLastUsedCustomReminderDatetime();

    if (this._editingExistingBookmark()) {
      this._initializeExistingBookmarkData();
    }
  },

  /**
   * We always want to save the bookmark unless the user specifically
   * clicks the save or cancel button to mimic browser behaviour.
   */
  onClose() {
    this._unbindKeyboardShortcuts();
    this._restoreGlobalShortcuts();
    if (!this._closeWithoutSaving && !this._savingBookmarkManually) {
      this._saveBookmark().catch(e => this._handleSaveError(e));
    }
    if (this.onCloseWithoutSaving && this._closeWithoutSaving) {
      this.onCloseWithoutSaving();
    }
  },

  _initializeExistingBookmarkData() {
    if (this._existingBookmarkHasReminder()) {
      let parsedReminderAt = this._parseCustomDateTime(this.model.reminderAt);
      this.setProperties({
        customReminderDate: parsedReminderAt.format("YYYY-MM-DD"),
        customReminderTime: parsedReminderAt.format("HH:mm"),
        selectedReminderType: REMINDER_TYPES.CUSTOM
      });
    }
  },

  _editingExistingBookmark() {
    return isPresent(this.model) && isPresent(this.model.id);
  },

  _existingBookmarkHasReminder() {
    return isPresent(this.model) && isPresent(this.model.reminderAt);
  },

  _loadLastUsedCustomReminderDatetime() {
    let lastTime = localStorage.lastCustomBookmarkReminderTime;
    let lastDate = localStorage.lastCustomBookmarkReminderDate;

    if (lastTime && lastDate) {
      let parsed = this._parseCustomDateTime(lastDate, lastTime);

      // can't set reminders in the past
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

  _bindKeyboardShortcuts() {
    KeyboardShortcuts.pause(GLOBAL_SHORTCUTS_TO_PAUSE);
    Object.keys(BOOKMARK_BINDINGS).forEach(shortcut => {
      KeyboardShortcuts.addShortcut(shortcut, () => {
        let binding = BOOKMARK_BINDINGS[shortcut];
        if (binding.args) {
          return this.send(binding.handler, ...binding.args);
        }
        this.send(binding.handler);
      });
    });
  },

  _unbindKeyboardShortcuts() {
    KeyboardShortcuts.unbind(BOOKMARK_BINDINGS);
  },

  _restoreGlobalShortcuts() {
    KeyboardShortcuts.unpause(GLOBAL_SHORTCUTS_TO_PAUSE);
  },

  @discourseComputed("model.reminderAt")
  showExistingReminderAt(existingReminderAt) {
    return isPresent(existingReminderAt);
  },

  @discourseComputed("model.id")
  showDelete(id) {
    return isPresent(id);
  },

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
      this.now().hour() < LATER_TODAY_CUTOFF_HOUR
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

  @discourseComputed("model.reminderAt")
  existingReminderAtFormatted(existingReminderAt) {
    return formattedReminderTime(existingReminderAt, this.userTimezone);
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

  _saveBookmark() {
    const reminderAt = this._reminderAt();
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
      name: this.model.name,
      post_id: this.model.postId,
      id: this.model.id
    };

    if (this._editingExistingBookmark()) {
      return ajax("/bookmarks/" + this.model.id, {
        type: "PUT",
        data
      }).then(() => {
        if (this.afterSave) {
          this.afterSave({
            reminderAt: reminderAtISO,
            reminderType: this.selectedReminderType,
            id: this.model.id,
            name: this.model.name
          });
        }
      });
    } else {
      return ajax("/bookmarks", { type: "POST", data }).then(response => {
        if (this.afterSave) {
          this.afterSave({
            reminderAt: reminderAtISO,
            reminderType: this.selectedReminderType,
            id: response.id,
            name: this.model.name
          });
        }
      });
    }
  },

  _deleteBookmark() {
    return ajax("/bookmarks/" + this.model.id, {
      type: "DELETE"
    }).then(response => {
      if (this.afterDelete) {
        this.afterDelete(response.topic_bookmarked);
      }
    });
  },

  _parseCustomDateTime(date, time) {
    let dateTime = isPresent(time) ? date + " " + time : date;
    return moment.tz(dateTime, this.userTimezone);
  },

  _defaultCustomReminderTime() {
    return `0${START_OF_DAY_HOUR}:00`;
  },

  _reminderAt() {
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
          this.customReminderTime || this._defaultCustomReminderTime()
        );
        const customDateTime = this._parseCustomDateTime(
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
    if (later.hour() >= LATER_TODAY_MAX_HOUR) {
      return later.hour(LATER_TODAY_MAX_HOUR).startOf("hour");
    }
    return later.minutes() < 30
      ? later.startOf("hour")
      : later.add(30, "minutes").startOf("hour");
  },

  laterThisWeek() {
    if (!this.showLaterThisWeek) {
      return;
    }
    return this.startOfDay(this.now().add(2, "days"));
  },

  _handleSaveError(e) {
    this._savingBookmarkManually = false;
    if (typeof e === "string") {
      bootbox.alert(e);
    } else {
      popupAjaxError(e);
    }
  },

  actions: {
    saveAndClose() {
      if (this._saving || this._deleting) {
        return;
      }

      this._saving = true;
      this._savingBookmarkManually = true;
      this._saveBookmark()
        .then(() => this.send("closeModal"))
        .catch(e => this._handleSaveError(e))
        .finally(() => (this._saving = false));
    },

    delete() {
      this._deleting = true;
      let deleteAction = () => {
        this._closeWithoutSaving = true;
        this._deleteBookmark()
          .then(() => {
            this._deleting = false;
            this.send("closeModal");
          })
          .catch(e => this._handleSaveError(e));
      };

      if (this._existingBookmarkHasReminder()) {
        bootbox.confirm(I18n.t("bookmarks.confirm_delete"), result => {
          if (result) {
            deleteAction();
          }
        });
      } else {
        deleteAction();
      }
    },

    closeWithoutSavingBookmark() {
      this._closeWithoutSaving = true;
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

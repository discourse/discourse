import {
  LATER_TODAY_CUTOFF_HOUR,
  MOMENT_THURSDAY,
  laterToday,
  now,
  parseCustomDatetime,
  tomorrow,
} from "discourse/lib/timeUtils";
import { isEmpty, isPresent } from "@ember/utils";
import { next, schedule } from "@ember/runloop";

import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import Controller from "@ember/controller";
import I18n from "I18n";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { Promise } from "rsvp";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/timeShortcut";

import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { or } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";

// global shortcuts that interfere with these modal shortcuts, they are rebound when the
// modal is closed
//
// c createTopic
// r replyToPost
// l toggle like
// d deletePost
// t replyAsNewTopic
const GLOBAL_SHORTCUTS_TO_PAUSE = ["c", "r", "l", "d", "t"];
const BOOKMARK_BINDINGS = {
  enter: { handler: "saveAndClose" },
  "l t": {
    handler: "selectReminderType",
    args: [TIME_SHORTCUT_TYPES.LATER_TODAY],
  },
  "l w": {
    handler: "selectReminderType",
    args: [TIME_SHORTCUT_TYPES.LATER_THIS_WEEK],
  },
  "n b d": {
    handler: "selectReminderType",
    args: [TIME_SHORTCUT_TYPES.NEXT_BUSINESS_DAY],
  },
  "n d": {
    handler: "selectReminderType",
    args: [TIME_SHORTCUT_TYPES.TOMORROW],
  },
  "n w": {
    handler: "selectReminderType",
    args: [TIME_SHORTCUT_TYPES.NEXT_WEEK],
  },
  "n b w": {
    handler: "selectReminderType",
    args: [TIME_SHORTCUT_TYPES.START_OF_NEXT_BUSINESS_WEEK],
  },
  "n m": {
    handler: "selectReminderType",
    args: [TIME_SHORTCUT_TYPES.NEXT_MONTH],
  },
  "c r": { handler: "selectReminderType", args: [TIME_SHORTCUT_TYPES.CUSTOM] },
  "n r": { handler: "selectReminderType", args: [TIME_SHORTCUT_TYPES.NONE] },
  "d d": { handler: "delete" },
};

export default Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,
  selectedReminderType: null,
  _closeWithoutSaving: false,
  _savingBookmarkManually: false,
  onCloseWithoutSaving: null,
  postDetectedLocalDate: null,
  postDetectedLocalTime: null,
  postDetectedLocalTimezone: null,
  prefilledDatetime: null,
  mouseTrap: null,
  userTimezone: null,
  showOptions: false,

  onShow() {
    this.setProperties({
      errorMessage: null,
      selectedReminderType: TIME_SHORTCUT_TYPES.NONE,
      _closeWithoutSaving: false,
      _savingBookmarkManually: false,
      postDetectedLocalDate: null,
      postDetectedLocalTime: null,
      postDetectedLocalTimezone: null,
      prefilledDatetime: null,
      userTimezone: this.currentUser.resolvedTimezone(this.currentUser),
      showOptions: false,
      model: this.model || {},
    });

    this._loadBookmarkOptions();
    this._bindKeyboardShortcuts();

    if (this._editingExistingBookmark()) {
      this._initializeExistingBookmarkData();
    }

    schedule("afterRender", () => {
      if (this.site.isMobileDevice) {
        document.getElementById("bookmark-name").blur();
      }
    });
  },

  /**
   * We always want to save the bookmark unless the user specifically
   * clicks the save or cancel button to mimic browser behaviour.
   */
  onClose(opts = {}) {
    if (opts.initiatedByCloseButton) {
      this._closeWithoutSaving = true;
    }

    this._unbindKeyboardShortcuts();
    this._restoreGlobalShortcuts();
    if (!this._closeWithoutSaving && !this._savingBookmarkManually) {
      this._saveBookmark().catch((e) => this._handleSaveError(e));
    }
    if (this.onCloseWithoutSaving && this._closeWithoutSaving) {
      this.onCloseWithoutSaving();
    }
  },

  _initializeExistingBookmarkData() {
    if (this._existingBookmarkHasReminder()) {
      this.setProperties({
        prefilledDatetime: this.model.reminderAt,
      });
    }
  },

  _editingExistingBookmark() {
    return isPresent(this.model) && isPresent(this.model.id);
  },

  _existingBookmarkHasReminder() {
    return isPresent(this.model) && isPresent(this.model.reminderAt);
  },

  _loadBookmarkOptions() {
    this.set(
      "autoDeletePreference",
      this.model.autoDeletePreference || this._preferredDeleteOption() || 0
    );

    // we want to make sure the options panel opens so the user
    // knows they have set these options previously. run next otherwise
    // the modal is not visible when it tries to slide down the options
    if (this.autoDeletePreference) {
      next(() => this.toggleOptionsPanel());
    }
  },

  _preferredDeleteOption() {
    let preferred = localStorage.bookmarkDeleteOption;
    if (preferred && preferred !== "") {
      preferred = parseInt(preferred, 10);
    }
    return preferred;
  },

  _bindKeyboardShortcuts() {
    KeyboardShortcuts.pause(GLOBAL_SHORTCUTS_TO_PAUSE);
    Object.keys(BOOKMARK_BINDINGS).forEach((shortcut) => {
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
  autoDeletePreferences: () => {
    return Object.keys(AUTO_DELETE_PREFERENCES).map((key) => {
      return {
        id: AUTO_DELETE_PREFERENCES[key],
        name: I18n.t(`bookmarks.auto_delete_preference.${key.toLowerCase()}`),
      };
    });
  },

  showPostLocalDate: or(
    "model.postDetectedLocalDate",
    "model.postDetectedLocalTime"
  ),

  @discourseComputed()
  customTimeShortcutOptions() {
    let customOptions = [];

    if (this.showPostLocalDate) {
      customOptions.push({
        icon: "globe-americas",
        id: TIME_SHORTCUT_TYPES.POST_LOCAL_DATE,
        label: "bookmarks.reminders.post_local_date",
        time: this.postLocalDate(),
        timeFormatted: this.postLocalDate().format(
          I18n.t("dates.long_no_year")
        ),
        hidden: false,
      });
    }

    return customOptions;
  },

  @discourseComputed()
  additionalTimeShortcutOptions() {
    let additional = [];

    let later = laterToday(this.userTimezone);
    if (
      !later.isSame(tomorrow(this.userTimezone), "date") &&
      now(this.userTimezone).hour() < LATER_TODAY_CUTOFF_HOUR
    ) {
      additional.push(TIME_SHORTCUT_TYPES.LATER_TODAY);
    }

    if (now(this.userTimezone).day() < MOMENT_THURSDAY) {
      additional.push(TIME_SHORTCUT_TYPES.LATER_THIS_WEEK);
    }

    return additional;
  },

  @discourseComputed("model.reminderAt")
  existingReminderAtFormatted(existingReminderAt) {
    return formattedReminderTime(existingReminderAt, this.userTimezone);
  },

  @discourseComputed("userTimezone")
  userHasTimezoneSet(userTimezone) {
    return !isEmpty(userTimezone);
  },

  _saveBookmark() {
    const reminderAt = this._reminderAt();
    const reminderAtISO = reminderAt ? reminderAt.toISOString() : null;

    if (this.selectedReminderType === TIME_SHORTCUT_TYPES.CUSTOM) {
      if (!reminderAt) {
        return Promise.reject(I18n.t("bookmarks.invalid_custom_datetime"));
      }
    }

    localStorage.bookmarkDeleteOption = this.autoDeletePreference;

    let reminderType;
    if (this.selectedReminderType === TIME_SHORTCUT_TYPES.NONE) {
      reminderType = null;
    } else if (
      this.selectedReminderType === TIME_SHORTCUT_TYPES.LAST_CUSTOM ||
      this.selectedReminderType === TIME_SHORTCUT_TYPES.POST_LOCAL_DATE
    ) {
      reminderType = TIME_SHORTCUT_TYPES.CUSTOM;
    } else {
      reminderType = this.selectedReminderType;
    }

    const data = {
      reminder_type: reminderType,
      reminder_at: reminderAtISO,
      name: this.model.name,
      post_id: this.model.postId,
      id: this.model.id,
      auto_delete_preference: this.autoDeletePreference,
    };

    if (this._editingExistingBookmark()) {
      return ajax("/bookmarks/" + this.model.id, {
        type: "PUT",
        data,
      }).then(() => {
        if (this.afterSave) {
          this.afterSave({
            reminderAt: reminderAtISO,
            reminderType: this.selectedReminderType,
            autoDeletePreference: this.autoDeletePreference,
            id: this.model.id,
            name: this.model.name,
          });
        }
      });
    } else {
      return ajax("/bookmarks", { type: "POST", data }).then((response) => {
        if (this.afterSave) {
          this.afterSave({
            reminderAt: reminderAtISO,
            reminderType: this.selectedReminderType,
            autoDeletePreference: this.autoDeletePreference,
            id: response.id,
            name: this.model.name,
          });
        }
      });
    }
  },

  _deleteBookmark() {
    return ajax("/bookmarks/" + this.model.id, {
      type: "DELETE",
    }).then((response) => {
      if (this.afterDelete) {
        this.afterDelete(response.topic_bookmarked);
      }
    });
  },

  _reminderAt() {
    if (!this.selectedReminderType) {
      return;
    }

    return this.selectedDateTime;
  },

  postLocalDate() {
    let parsedPostLocalDate = parseCustomDatetime(
      this.model.postDetectedLocalDate,
      this.model.postDetectedLocalTime,
      this.userTimezone,
      this.model.postDetectedLocalTimezone
    );

    if (!this.model.postDetectedLocalTime) {
      return this.startOfDay(parsedPostLocalDate);
    }

    return parsedPostLocalDate;
  },

  _handleSaveError(e) {
    this._savingBookmarkManually = false;
    if (typeof e === "string") {
      bootbox.alert(e);
    } else {
      popupAjaxError(e);
    }
  },

  @action
  toggleOptionsPanel() {
    if (this.showOptions) {
      $(".bookmark-options-panel").slideUp("fast");
    } else {
      $(".bookmark-options-panel").slideDown("fast");
    }
    this.toggleProperty("showOptions");
  },

  @action
  saveAndClose() {
    if (this._saving || this._deleting) {
      return;
    }

    this._saving = true;
    this._savingBookmarkManually = true;
    return this._saveBookmark()
      .then(() => this.send("closeModal"))
      .catch((e) => this._handleSaveError(e))
      .finally(() => (this._saving = false));
  },

  @action
  delete() {
    this._deleting = true;
    let deleteAction = () => {
      this._closeWithoutSaving = true;
      this._deleteBookmark()
        .then(() => {
          this._deleting = false;
          this.send("closeModal");
        })
        .catch((e) => this._handleSaveError(e));
    };

    if (this._existingBookmarkHasReminder()) {
      bootbox.confirm(I18n.t("bookmarks.confirm_delete"), (result) => {
        if (result) {
          deleteAction();
        }
      });
    } else {
      deleteAction();
    }
  },

  @action
  closeWithoutSavingBookmark() {
    this._closeWithoutSaving = true;
    this.send("closeModal");
  },

  @action
  onTimeSelected(type, time) {
    this.setProperties({ selectedReminderType: type, selectedDateTime: time });

    // if the type is custom, we need to wait for the user to click save, as
    // they could still be adjusting the date and time
    if (type !== TIME_SHORTCUT_TYPES.CUSTOM) {
      return this.saveAndClose();
    }
  },
});

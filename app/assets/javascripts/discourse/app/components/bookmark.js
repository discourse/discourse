import {
  LATER_TODAY_CUTOFF_HOUR,
  MOMENT_THURSDAY,
  laterToday,
  now,
  parseCustomDatetime,
  startOfDay,
  tomorrow,
} from "discourse/lib/timeUtils";
import { isEmpty, isPresent } from "@ember/utils";
import { next } from "@ember/runloop";

import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import Component from "@ember/component";
import I18n from "I18n";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import { Promise } from "rsvp";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/timeShortcut";

import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import discourseComputed, { on } from "discourse-common/utils/decorators";
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
const GLOBAL_SHORTCUTS_TO_PAUSE = ["d"];
const BOOKMARK_BINDINGS = {
  enter: { handler: "saveAndClose" },
  "d d": { handler: "delete" },
};

export default Component.extend({
  tagName: "",

  init() {
    this._super(...arguments);

    this.setProperties({
      errorMessage: null,
      selectedReminderType: TIME_SHORTCUT_TYPES.NONE,
      _closeWithoutSaving: false,
      _savingBookmarkManually: false,
      _saving: false,
      _deleting: false,
      postDetectedLocalDate: null,
      postDetectedLocalTime: null,
      postDetectedLocalTimezone: null,
      prefilledDatetime: null,
      userTimezone: this.currentUser.resolvedTimezone(this.currentUser),
      showOptions: false,
    });

    this.registerOnCloseHandler(this._onModalClose.bind(this));

    this._loadBookmarkOptions();
    this._bindKeyboardShortcuts();

    if (this._editingExistingBookmark()) {
      this._initializeExistingBookmarkData();
    }

    this._loadPostLocalDates();
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

  _loadPostLocalDates() {
    let postEl = document.querySelector(
      `[data-post-id="${this.model.postId}"]`
    );
    let localDateEl = null;
    if (postEl) {
      localDateEl = postEl.querySelector(".discourse-local-date");
    }

    if (localDateEl) {
      this.setProperties({
        postDetectedLocalDate: localDateEl.dataset.date,
        postDetectedLocalTime: localDateEl.dataset.time,
        postDetectedLocalTimezone: localDateEl.dataset.timezone,
      });
    }
  },

  _showPostLocalDate: or("postDetectedLocalDate", "postDetectedLocalTime"),

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

  _postLocalDate() {
    let parsedPostLocalDate = parseCustomDatetime(
      this.postDetectedLocalDate,
      this.postDetectedLocalTime,
      this.userTimezone,
      this.postDetectedLocalTimezone
    );

    if (!this.postDetectedLocalTime) {
      return startOfDay(parsedPostLocalDate);
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

  _onModalClose(initiatedByCloseButton) {
    // we want to close without saving if the user already saved
    // manually or deleted the bookmark, as well as when the modal
    // is just closed with the X button
    this._closeWithoutSaving =
      this._closeWithoutSaving || initiatedByCloseButton;

    this._unbindKeyboardShortcuts();
    this._restoreGlobalShortcuts();

    if (!this._closeWithoutSaving && !this._savingBookmarkManually) {
      this._saveBookmark().catch((e) => this._handleSaveError(e));
    }
    if (this.onCloseWithoutSaving && this._closeWithoutSaving) {
      this.onCloseWithoutSaving();
    }
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

  @discourseComputed()
  customTimeShortcutOptions() {
    let customOptions = [];

    if (this._showPostLocalDate) {
      customOptions.push({
        icon: "globe-americas",
        id: TIME_SHORTCUT_TYPES.POST_LOCAL_DATE,
        label: "bookmarks.reminders.post_local_date",
        time: this._postLocalDate(),
        timeFormatted: this._postLocalDate().format(
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

  @on("didInsertElement")
  blurName() {
    if (this.site.isMobileDevice) {
      document.getElementById("bookmark-name").blur();
    }
  },

  @action
  saveAndClose() {
    if (this._saving || this._deleting) {
      return;
    }

    this._saving = true;
    this._savingBookmarkManually = true;
    return this._saveBookmark()
      .then(() => this.closeModal())
      .catch((e) => this._handleSaveError(e))
      .finally(() => (this._saving = false));
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
  delete() {
    this._deleting = true;
    let deleteAction = () => {
      this._closeWithoutSaving = true;
      this._deleteBookmark()
        .then(() => {
          this._deleting = false;
          this.closeModal();
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
    this.closeModal();
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

  @action
  selectPostLocalDate(date) {
    this.setProperties({
      selectedReminderType: this.reminderTypes.POST_LOCAL_DATE,
      postLocalDate: date,
    });
    return this.saveAndClose();
  },
});

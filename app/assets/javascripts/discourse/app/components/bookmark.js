import {
  LATER_TODAY_CUTOFF_HOUR,
  MOMENT_THURSDAY,
  laterToday,
  now,
  parseCustomDatetime,
  startOfDay,
  tomorrow,
} from "discourse/lib/time-utils";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import Component from "@ember/component";
import I18n from "I18n";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import Mousetrap from "mousetrap";
import { Promise } from "rsvp";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/time-shortcut";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { and, notEmpty } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { later } from "@ember/runloop";

const BOOKMARK_BINDINGS = {
  enter: { handler: "saveAndClose" },
  "d d": { handler: "delete" },
};

export default Component.extend({
  tagName: "",

  errorMessage: null,
  selectedReminderType: null,
  _closeWithoutSaving: null,
  _savingBookmarkManually: null,
  _saving: null,
  _deleting: null,
  postDetectedLocalDate: null,
  postDetectedLocalTime: null,
  postDetectedLocalTimezone: null,
  prefilledDatetime: null,
  userTimezone: null,
  showOptions: null,
  model: null,

  afterSave: null,

  @on("init")
  _setup() {
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

    if (this.editingExistingBookmark) {
      this._initializeExistingBookmarkData();
    }

    this._loadPostLocalDates();
  },

  @on("didInsertElement")
  _prepareUI() {
    later(() => {
      if (this.site.isMobileDevice) {
        document.getElementById("bookmark-name").blur();
      }
    });

    // we want to make sure the options panel opens so the user
    // knows they have set these options previously.
    if (this.autoDeletePreference) {
      this.toggleOptionsPanel();
    }
  },

  _initializeExistingBookmarkData() {
    if (this.existingBookmarkHasReminder) {
      this.set("prefilledDatetime", this.model.reminderAt);

      let parsedDatetime = parseCustomDatetime(
        this.prefilledDatetime,
        null,
        this.userTimezone
      );

      this.set("selectedDatetime", parsedDatetime);
    }
  },

  _loadBookmarkOptions() {
    this.set(
      "autoDeletePreference",
      this.model.autoDeletePreference || this._preferredDeleteOption() || 0
    );
  },

  _preferredDeleteOption() {
    let preferred = localStorage.bookmarkDeleteOption;
    if (preferred && preferred !== "") {
      preferred = parseInt(preferred, 10);
    }
    return preferred;
  },

  _bindKeyboardShortcuts() {
    KeyboardShortcuts.pause();

    this._mousetrap = new Mousetrap();
    Object.keys(BOOKMARK_BINDINGS).forEach((shortcut) => {
      this._mousetrap.bind(shortcut, () => {
        let binding = BOOKMARK_BINDINGS[shortcut];
        this.send(binding.handler);
        return false;
      });
    });
  },

  _loadPostLocalDates() {
    let postEl = document.querySelector(
      `[data-post-id="${this.model.postId}"]`
    );
    let localDateEl;
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

  _saveBookmark() {
    let reminderAt;
    if (this.selectedReminderType) {
      reminderAt = this.selectedDatetime;
    }

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

    if (this.editingExistingBookmark) {
      return ajax(`/bookmarks/${this.model.id}`, {
        type: "PUT",
        data,
      }).then((response) => {
        this._executeAfterSave(response, reminderAtISO);
      });
    } else {
      return ajax("/bookmarks", { type: "POST", data }).then((response) => {
        this._executeAfterSave(response, reminderAtISO);
      });
    }
  },

  _executeAfterSave(response, reminderAtISO) {
    if (!this.afterSave) {
      return;
    }
    this.afterSave({
      reminderAt: reminderAtISO,
      reminderType: this.selectedReminderType,
      autoDeletePreference: this.autoDeletePreference,
      id: this.model.id || response.id,
      name: this.model.name,
    });
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

    if (!this._closeWithoutSaving && !this._savingBookmarkManually) {
      this._saveBookmark().catch((e) => this._handleSaveError(e));
    }
    if (this.onCloseWithoutSaving && this._closeWithoutSaving) {
      this.onCloseWithoutSaving();
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    this._mousetrap.reset();
    KeyboardShortcuts.unpause();
  },

  showExistingReminderAt: notEmpty("model.reminderAt"),
  showDelete: notEmpty("model.id"),
  userHasTimezoneSet: notEmpty("userTimezone"),
  editingExistingBookmark: and("model", "model.id"),
  existingBookmarkHasReminder: and("model", "model.reminderAt"),

  @discourseComputed("postDetectedLocalDate", "postDetectedLocalTime")
  showPostLocalDate(postDetectedLocalDate, postDetectedLocalTime) {
    if (!postDetectedLocalTime || !postDetectedLocalDate) {
      return;
    }

    let postLocalDateTime = this._postLocalDate();
    if (postLocalDateTime < now(this.userTimezone)) {
      return;
    }

    return true;
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

    if (this.showPostLocalDate) {
      customOptions.push({
        icon: "globe-americas",
        id: TIME_SHORTCUT_TYPES.POST_LOCAL_DATE,
        label: "time_shortcut.post_local_date",
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

    if (
      !laterToday(this.userTimezone).isSame(
        tomorrow(this.userTimezone),
        "date"
      ) &&
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
    if (!this.model.id) {
      return;
    }

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

    if (this.existingBookmarkHasReminder) {
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
    this.setProperties({ selectedReminderType: type, selectedDatetime: time });

    // if the type is custom, we need to wait for the user to click save, as
    // they could still be adjusting the date and time
    if (
      ![TIME_SHORTCUT_TYPES.CUSTOM, TIME_SHORTCUT_TYPES.RELATIVE].includes(type)
    ) {
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

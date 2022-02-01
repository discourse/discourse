import { now, parseCustomDatetime, startOfDay } from "discourse/lib/time-utils";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import Component from "@ember/component";
import I18n from "I18n";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import ItsATrap from "@discourse/itsatrap";
import { Promise } from "rsvp";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/time-shortcut";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import discourseComputed, { bind, on } from "discourse-common/utils/decorators";
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
  _itsatrap: null,
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
      _itsatrap: new ItsATrap(),
    });

    this.registerOnCloseHandler(this._onModalClose);

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

    Object.keys(BOOKMARK_BINDINGS).forEach((shortcut) => {
      this._itsatrap.bind(shortcut, () => {
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

    const data = {
      reminder_at: reminderAtISO,
      name: this.model.name,
      post_id: this.model.postId,
      id: this.model.id,
      auto_delete_preference: this.autoDeletePreference,
      for_topic: this.model.forTopic,
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
      reminder_at: reminderAtISO,
      for_topic: this.model.forTopic,
      auto_delete_preference: this.autoDeletePreference,
      post_id: this.model.postId,
      id: this.model.id || response.id,
      name: this.model.name,
      topic_id: this.model.topicId,
    });
  },

  _deleteBookmark() {
    return ajax("/bookmarks/" + this.model.id, {
      type: "DELETE",
    }).then((response) => {
      if (this.afterDelete) {
        this.afterDelete(response.topic_bookmarked, this.model.id);
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

  @bind
  _onModalClose(closeOpts) {
    // we want to close without saving if the user already saved
    // manually or deleted the bookmark, as well as when the modal
    // is just closed with the X button
    this._closeWithoutSaving =
      this._closeWithoutSaving ||
      closeOpts.initiatedByCloseButton ||
      closeOpts.initiatedByESC;

    if (!this._closeWithoutSaving && !this._savingBookmarkManually) {
      this._saveBookmark().catch((e) => this._handleSaveError(e));
    }
    if (this.onCloseWithoutSaving && this._closeWithoutSaving) {
      this.onCloseWithoutSaving();
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    this._itsatrap?.destroy();
    this.set("_itsatrap", null);
    KeyboardShortcuts.unpause();
  },

  showExistingReminderAt: notEmpty("model.reminderAt"),
  showDelete: notEmpty("model.id"),
  userHasTimezoneSet: notEmpty("userTimezone"),
  editingExistingBookmark: and("model", "model.id"),
  existingBookmarkHasReminder: and("model", "model.id", "model.reminderAt"),

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
        timeFormatKey: "dates.long_no_year",
        hidden: false,
      });
    }

    return customOptions;
  },

  @discourseComputed("existingBookmarkHasReminder")
  customTimeShortcutLabels(existingBookmarkHasReminder) {
    const labels = {};
    if (existingBookmarkHasReminder) {
      labels[TIME_SHORTCUT_TYPES.NONE] =
        "bookmarks.remove_reminder_keep_bookmark";
    }
    return labels;
  },

  @discourseComputed("editingExistingBookmark", "existingBookmarkHasReminder")
  hiddenTimeShortcutOptions(
    editingExistingBookmark,
    existingBookmarkHasReminder
  ) {
    if (editingExistingBookmark && !existingBookmarkHasReminder) {
      return [TIME_SHORTCUT_TYPES.NONE];
    }

    return [];
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

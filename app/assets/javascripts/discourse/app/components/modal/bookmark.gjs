import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { and, notEmpty } from "@ember/object/computed";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import ItsATrap from "@discourse/itsatrap";
import { Promise } from "rsvp";
import DButton from "discourse/components/d-button";
import DModal, {
  CLOSE_INITIATED_BY_CLICK_OUTSIDE,
} from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import TimeShortcutPicker from "discourse/components/time-shortcut-picker";
import basePath from "discourse/helpers/base-path";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { extractError } from "discourse/lib/ajax-error";
import { formattedReminderTime } from "discourse/lib/bookmark";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import discourseLater from "discourse/lib/later";
import { sanitize } from "discourse/lib/text";
import {
  defaultTimeShortcuts,
  TIME_SHORTCUT_TYPES,
} from "discourse/lib/time-shortcut";
import { now, parseCustomDatetime, startOfDay } from "discourse/lib/time-utils";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const BOOKMARK_BINDINGS = {
  enter: { handler: "saveAndClose" },
  "d d": { handler: "delete" },
};

export default class BookmarkModal extends Component {
  @service dialog;
  @service currentUser;
  @service site;
  @service bookmarkApi;

  @tracked postDetectedLocalDate = null;
  @tracked postDetectedLocalTime = null;
  @tracked postDetectedLocalTimezone = null;
  @tracked prefilledDatetime = null;
  @tracked flash = null;
  @tracked userTimezone = this.currentUser.user_option.timezone;
  @tracked showOptions = this.args.model.bookmark.id ? true : false;

  @notEmpty("userTimezone") userHasTimezoneSet;

  @notEmpty("bookmark.id") showDelete;

  @notEmpty("bookmark.id") editingExistingBookmark;

  @and("bookmark.id", "bookmark.reminderAt") existingBookmarkHasReminder;

  @tracked _closeWithoutSaving = false;
  @tracked _savingBookmarkManually = false;
  @tracked _saving = false;
  @tracked _deleting = false;

  _itsatrap = new ItsATrap();

  willDestroy() {
    super.willDestroy(...arguments);
    this._itsatrap?.destroy();
    this._itsatrap = null;
    KeyboardShortcuts.unpause();
  }

  get bookmark() {
    return this.args.model.bookmark;
  }

  get modalTitle() {
    return i18n(this.bookmark.id ? "bookmarks.edit" : "bookmarks.create");
  }

  get autoDeletePreferences() {
    return Object.keys(AUTO_DELETE_PREFERENCES).map((key) => {
      return {
        id: AUTO_DELETE_PREFERENCES[key],
        name: i18n(`bookmarks.auto_delete_preference.${key.toLowerCase()}`),
      };
    });
  }

  get showExistingReminderAt() {
    return (
      this.bookmark.reminderAt &&
      Date.parse(this.bookmark.reminderAt) > new Date().getTime()
    );
  }

  get existingReminderAtFormatted() {
    return formattedReminderTime(this.bookmark.reminderAt, this.userTimezone);
  }

  get timeOptions() {
    const options = defaultTimeShortcuts(this.userTimezone);

    if (this.showPostLocalDate) {
      options.push({
        icon: "globe-americas",
        id: TIME_SHORTCUT_TYPES.POST_LOCAL_DATE,
        label: "time_shortcut.post_local_date",
        time: this.#parsedPostLocalDateTime(),
        timeFormatKey: "dates.long_no_year",
        hidden: false,
      });
    }

    return options;
  }

  get showPostLocalDate() {
    if (!this.postDetectedLocalTime || !this.postDetectedLocalDate) {
      return false;
    }

    if (this.#parsedPostLocalDateTime() < now(this.userTimezone)) {
      return false;
    }

    return true;
  }

  get hiddenTimeShortcutOptions() {
    if (this.editingExistingBookmark && !this.existingBookmarkHasReminder) {
      return [TIME_SHORTCUT_TYPES.NONE];
    }

    return [];
  }

  get customTimeShortcutLabels() {
    const labels = {};
    if (this.existingBookmarkHasReminder) {
      labels[TIME_SHORTCUT_TYPES.NONE] =
        "bookmarks.remove_reminder_keep_bookmark";
    }
    return labels;
  }

  @action
  didInsert() {
    discourseLater(() => {
      if (this.site.isMobileDevice) {
        document.getElementById("bookmark-name").blur();
      }
    });

    if (!this.args.model.bookmark.id) {
      document.getElementById("tap_tile_none").classList.add("active");
    }

    this.#bindKeyboardShortcuts();
    this.#initializeExistingBookmarkData();
    this.#loadPostLocalDates();
  }

  @action
  saveAndClose() {
    this.flash = null;
    if (this._saving || this._deleting) {
      return;
    }

    this._saving = true;
    this._savingBookmarkManually = true;
    return this.#saveBookmark()
      .then(() => this.args.closeModal())
      .catch((error) => this.#handleSaveError(error))
      .finally(() => {
        this._saving = false;
      });
  }

  @action
  toggleShowOptions() {
    this.showOptions = !this.showOptions;
  }

  @action
  onTimeSelected(type, time) {
    this.bookmark.selectedReminderType = type;
    this.bookmark.selectedDatetime = time;
    this.bookmark.reminderAt = time;

    // If the type is custom, we need to wait for the user to click save, as
    // they could still be adjusting the date and time
    if (
      ![TIME_SHORTCUT_TYPES.CUSTOM, TIME_SHORTCUT_TYPES.RELATIVE].includes(type)
    ) {
      return this.saveAndClose();
    }
  }

  @action
  closingModal(closeModalArgs) {
    // If the user clicks outside the modal we save automatically for them,
    // as long as they are not already saving manually or deleting the bookmark.
    if (
      closeModalArgs.initiatedBy === CLOSE_INITIATED_BY_CLICK_OUTSIDE &&
      !this._closeWithoutSaving &&
      !this._savingBookmarkManually
    ) {
      this.#saveBookmark()
        .catch((e) => this.#handleSaveError(e))
        .then(() => {
          this.args.closeModal(closeModalArgs);
        });
    } else {
      this.args.closeModal(closeModalArgs);
    }
  }

  @action
  closeWithoutSavingBookmark() {
    this._closeWithoutSaving = true;
    this.args.closeModal({ closeWithoutSaving: this._closeWithoutSaving });
  }

  @action
  delete() {
    if (!this.bookmark.id) {
      return;
    }

    this._deleting = true;
    const deleteAction = () => {
      this._closeWithoutSaving = true;
      this.#deleteBookmark()
        .then(() => {
          this._deleting = false;
          this.args.closeModal({
            closeWithoutSaving: this._closeWithoutSaving,
          });
        })
        .catch((error) => this.#handleSaveError(error));
    };

    if (this.existingBookmarkHasReminder) {
      this.dialog.deleteConfirm({
        message: i18n("bookmarks.confirm_delete"),
        didConfirm: () => deleteAction(),
      });
    } else {
      deleteAction();
    }
  }

  #parsedPostLocalDateTime() {
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
  }

  #saveBookmark() {
    if (this.bookmark.selectedReminderType === TIME_SHORTCUT_TYPES.CUSTOM) {
      if (!this.bookmark.reminderAtISO) {
        return Promise.reject(i18n("bookmarks.invalid_custom_datetime"));
      }
    }

    if (this.editingExistingBookmark) {
      return this.bookmarkApi.update(this.bookmark).then(() => {
        this.args.model.afterSave?.(this.bookmark);
      });
    } else {
      return this.bookmarkApi.create(this.bookmark).then(() => {
        this.args.model.afterSave?.(this.bookmark);
      });
    }
  }

  #deleteBookmark() {
    return this.bookmarkApi.delete(this.bookmark.id).then((response) => {
      this.args.model.afterDelete?.(response, this.bookmark.id);
    });
  }

  #handleSaveError(error) {
    this._savingBookmarkManually = false;
    if (typeof error === "string") {
      this.flash = sanitize(error);
    } else {
      this.flash = sanitize(extractError(error));
    }
  }

  #bindKeyboardShortcuts() {
    KeyboardShortcuts.pause();

    Object.keys(BOOKMARK_BINDINGS).forEach((shortcut) => {
      this._itsatrap.bind(shortcut, () => {
        const binding = BOOKMARK_BINDINGS[shortcut];
        this[binding.handler]();
        return false;
      });
    });
  }

  #initializeExistingBookmarkData() {
    if (!this.existingBookmarkHasReminder || !this.editingExistingBookmark) {
      return;
    }

    this.prefilledDatetime = this.bookmark.reminderAt;
    this.bookmark.selectedDatetime = parseCustomDatetime(
      this.prefilledDatetime,
      null,
      this.userTimezone
    );
  }

  // If we detect we are bookmarking a post which has local-date data
  // in it, we can preload that date + time into the form to use as the
  // bookmark reminder date + time.
  #loadPostLocalDates() {
    if (this.bookmark.bookmarkableType !== "Post") {
      return;
    }

    const postEl = document.querySelector(
      `[data-post-id="${this.bookmark.bookmarkableId}"]`
    );
    const localDateEl = postEl?.querySelector(".discourse-local-date");

    if (localDateEl) {
      this.postDetectedLocalDate = localDateEl.dataset.date;
      this.postDetectedLocalTime = localDateEl.dataset.time;
      this.postDetectedLocalTimezone = localDateEl.dataset.timezone;
    }
  }

  <template>
    <DModal
      @closeModal={{this.closingModal}}
      @title={{this.modalTitle}}
      @flash={{this.flash}}
      @flashType="error"
      id="bookmark-reminder-modal"
      class="bookmark-reminder-modal"
      data-bookmark-id={{this.bookmark.id}}
      {{didInsert this.didInsert}}
    >
      <:headerPrimaryAction>
        <DButton
          @label="bookmarks.save"
          @action={{this.saveAndClose}}
          @title="modal.close"
          class="btn-transparent btn-primary"
        />
      </:headerPrimaryAction>

      <:body>
        <div class="control-group bookmark-name-wrap">
          <Input
            id="bookmark-name"
            @value={{this.bookmark.name}}
            name="bookmark-name"
            class="bookmark-name"
            placeholder={{i18n "post.bookmarks.name_placeholder"}}
            aria-label={{i18n "post.bookmarks.name_input_label"}}
          />
          <DButton
            @icon="gear"
            @action={{this.toggleShowOptions}}
            @ariaLabel="post.bookmarks.options"
            @title="post.bookmarks.options"
            class="bookmark-options-button"
          />
        </div>

        {{#if this.showOptions}}
          <div class="bookmark-options-panel">
            <label
              class="control-label"
              for="bookmark_auto_delete_preference"
            >{{i18n "bookmarks.auto_delete_preference.label"}}</label>
            <ComboBox
              @content={{this.autoDeletePreferences}}
              @value={{this.bookmark.autoDeletePreference}}
              @id="bookmark-auto-delete-preference"
              @onChange={{fn (mut this.bookmark.autoDeletePreference)}}
              class="bookmark-option-selector"
            />
          </div>
        {{/if}}

        {{#if this.showExistingReminderAt}}
          <div class="alert alert-info existing-reminder-at-alert">
            {{icon "far-clock"}}
            <span>{{i18n
                "bookmarks.reminders.existing_reminder"
                at_date_time=this.existingReminderAtFormatted
              }}</span>
          </div>
        {{/if}}

        <div class="control-group">
          <label class="control-label">
            {{i18n "post.bookmarks.set_reminder"}}
          </label>

          {{#if this.userHasTimezoneSet}}
            <TimeShortcutPicker
              @timeShortcuts={{this.timeOptions}}
              @prefilledDatetime={{this.prefilledDatetime}}
              @onTimeSelected={{this.onTimeSelected}}
              @hiddenOptions={{this.hiddenTimeShortcutOptions}}
              @customLabels={{this.customTimeShortcutLabels}}
              @_itsatrap={{this._itsatrap}}
            />
          {{else}}
            <div class="alert alert-info">{{htmlSafe
                (i18n "bookmarks.no_timezone" basePath=(basePath))
              }}</div>
          {{/if}}
        </div>
      </:body>

      <:footer>
        <DButton
          @label="bookmarks.save"
          @action={{this.saveAndClose}}
          id="save-bookmark"
          class="btn-primary"
        />
        <DModalCancel @close={{this.closeWithoutSavingBookmark}} />
        {{#if this.showDelete}}
          <DButton
            @icon="trash-can"
            @action={{this.delete}}
            @ariaLabel="post.bookmarks.actions.delete_bookmark.name"
            @title="post.bookmarks.actions.delete_bookmark.name"
            id="delete-bookmark"
            class="delete-bookmark btn-danger"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}

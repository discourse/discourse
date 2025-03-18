import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { and, notEmpty } from "@ember/object/computed";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import ItsATrap from "@discourse/itsatrap";
import { Promise } from "rsvp";
import BookmarkForm from "discourse/components/bookmark-form";
import DButton from "discourse/components/d-button";
import DModal, {
  CLOSE_INITIATED_BY_CLICK_OUTSIDE,
} from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { extractError } from "discourse/lib/ajax-error";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import { sanitize } from "discourse/lib/text";
import { TIME_SHORTCUT_TYPES } from "discourse/lib/time-shortcut";
import { parseCustomDatetime } from "discourse/lib/time-utils";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";

const BOOKMARK_BINDINGS = {
  enter: { handler: "saveAndClose" },
  "d d": { handler: "delete" },
};

export default class BookmarkModal extends Component {
  @service dialog;
  @service currentUser;

  @service bookmarkApi;

  @tracked formApi;

  @tracked postDetectedLocalDate = null;
  @tracked postDetectedLocalTime = null;
  @tracked postDetectedLocalTimezone = null;
  @tracked prefilledDatetime = null;
  @tracked flash = null;
  @tracked userTimezone = this.currentUser.user_option.timezone;

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

  get targetModel() {
    return this.args.model.targetModel;
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

  @action
  didInsert() {
    this.#bindKeyboardShortcuts();
    this.#initializeExistingBookmarkData();
  }

  @action
  registerFormApi(api) {
    this.formApi = api;
  }

  @action
  saveAndClose(data) {
    this.flash = null;
    if (this._saving || this._deleting) {
      return;
    }

    this._saving = true;
    this._savingBookmarkManually = true;
    return this.#saveBookmark(data)
      .then(() => this.args.closeModal())
      .catch((error) => this.#handleSaveError(error))
      .finally(() => {
        this._saving = false;
      });
  }

  @action
  onTimeSelected(type, time) {
    this.bookmark.selectedReminderType = type;
    this.bookmark.selectedDatetime = time;
    this.bookmark.reminderAt = time;

    return this.saveAndClose();
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
      this.formApi.submit();
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

  #saveBookmark(data) {
    this.bookmark.reminderAt = data.reminderAt;
    this.bookmark.name = data.name;
    this.bookmark.autoDeletePreference = parseInt(
      data.autoDeletePreference,
      10
    );

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
          @action={{this.formApi.submit}}
          @title="modal.close"
          class="btn-transparent btn-primary"
        />
      </:headerPrimaryAction>

      <:body>
        <BookmarkForm
          @registerFormApi={{this.registerFormApi}}
          @submit={{this.saveAndClose}}
          @bookmark={{this.bookmark}}
          @targetModel={{this.targetModel}}
        />
      </:body>

      <:footer>
        <DButton
          @label="bookmarks.save"
          @action={{this.formApi.submit}}
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

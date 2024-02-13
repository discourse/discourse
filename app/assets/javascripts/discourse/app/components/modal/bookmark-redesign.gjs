import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { and, notEmpty } from "@ember/object/computed";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import CalendarDateTimeInput from "discourse/components/calendar-date-time-input";
import DButton from "discourse/components/d-button";
import DModal, {
  CLOSE_INITIATED_BY_CLICK_OUTSIDE,
} from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { renderAvatar } from "discourse/helpers/user-avatar";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { excerpt, sanitize } from "discourse/lib/text";
import { now, parseCustomDatetime } from "discourse/lib/time-utils";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import i18n from "discourse-common/helpers/i18n";
import discourseLater from "discourse-common/lib/later";
import I18n from "I18n";
import ComboBox from "select-kit/components/combo-box";

export default class BookmarkRedesignModal extends Component {
  @service dialog;
  @service currentUser;
  @service site;

  @tracked postDetectedLocalDate = null;
  @tracked postDetectedLocalTime = null;
  @tracked postDetectedLocalTimezone = null;
  @tracked prefilledDatetime = null;
  @tracked flash = null;
  @tracked userTimezone = this.currentUser.user_option.timezone;
  @tracked showOptions = this.args.model.bookmark.id ? true : false;
  @tracked reminderDate = null;
  @tracked reminderTime = null;
  @tracked defaultFutureAutoDeletePreference = false;

  @notEmpty("userTimezone") userHasTimezoneSet;

  @notEmpty("bookmark.id") editingExistingBookmark;

  @and("bookmark.id", "bookmark.reminderAt") existingBookmarkHasReminder;

  @tracked _closeWithoutSaving = false;
  @tracked _savingBookmarkManually = false;
  @tracked _saving = false;
  @tracked _deleting = false;

  get avatar() {
    return htmlSafe(renderAvatar(this.args.model.user, { imageSize: "small" }));
  }

  get excerpt() {
    return excerpt(this.args.model.context.cooked, 300);
  }

  get minDate() {
    return now(this.currentUser.user_option.timezone).toDate();
  }

  get bookmark() {
    return this.args.model.bookmark;
  }

  get modalTitle() {
    return I18n.t(this.bookmark.id ? "bookmarks.edit" : "bookmarks.create");
  }

  get bookmarkAfterNotificationModes() {
    return Object.keys(AUTO_DELETE_PREFERENCES).map((key) => {
      return {
        value: AUTO_DELETE_PREFERENCES[key],
        name: I18n.t(`bookmarks.auto_delete_preference.${key.toLowerCase()}`),
      };
    });
  }

  @action
  didInsert() {
    discourseLater(() => {
      if (this.site.isMobileDevice) {
        document.getElementById("bookmark-name").blur();
      }
    });

    this.#initializeExistingBookmarkData();
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
  changeSelectedDate(date) {
    this.reminderDate = date;
  }

  @action
  changeSelectedTime(time) {
    this.reminderTime = time;
  }

  #saveBookmark() {
    if (this.editingExistingBookmark) {
      return ajax(`/bookmarks/${this.bookmark.id}`, {
        type: "PUT",
        data: this.bookmark.saveData,
      }).then(() => {
        this.args.model.afterSave?.(this.bookmark.saveData);
      });
    } else {
      return ajax("/bookmarks", {
        type: "POST",
        data: this.bookmark.saveData,
      }).then((response) => {
        this.bookmark.id = response.id;
        this.args.model.afterSave?.(this.bookmark.saveData);
      });
    }
  }

  #handleSaveError(error) {
    this._savingBookmarkManually = false;
    if (typeof error === "string") {
      this.flash = sanitize(error);
    } else {
      this.flash = sanitize(extractError(error));
    }
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
      class="bookmark-reminder-modal bookmark-with-reminder bookmark-redesigned-modal"
      data-bookmark-id={{this.bookmark.id}}
      {{didInsert this.didInsert}}
    >
      <:body>
        <div class="bookmark-context">
          <div class="bookmark-context__user-avatar">
            <div
              role="button"
              class="clickable"
              data-user-card={{@model.context.user.username}}
            >
              {{this.avatar}}
            </div>

            <span
              class="bookmark-context__username"
            >{{@model.context.user.username}}</span>

            {{#if @model.contextTitle}}
              <span
                class="bookmark-context__title"
              >{{@model.contextTitle}}</span>
            {{/if}}
          </div>

          {{! TODO (martin) We need to decorate the #hashtags here so they get their colours }}
          <div class="bookmark-context__excerpt">{{htmlSafe this.excerpt}}</div>
        </div>

        <div class="control-group bookmark-name-wrap">
          <Input
            id="bookmark-name"
            @value={{this.bookmark.name}}
            name="bookmark-name"
            class="bookmark-name"
            @enter={{action "saveAndClose"}}
            placeholder={{i18n "post.bookmarks.name_placeholder"}}
            aria-label={{i18n "post.bookmarks.name_input_label"}}
          />
        </div>

        <CalendarDateTimeInput
          @datePickerId="bookmark"
          @date={{this.reminderDate}}
          @time={{this.reminderTime}}
          @minDate={{this.minDate}}
          @onChangeDate={{action this.changeSelectedDate}}
          @onChangeTime={{action this.changeSelectedTime}}
        />

        <div class="control-group bookmark-auto-delete-wrap">
          <label
            class="control-label"
            for="bookmark_auto_delete_preference"
          >{{i18n
              "bookmarks.auto_delete_preference.after_reminder_label"
            }}</label>

          <ComboBox
            @valueProperty="value"
            @content={{this.bookmarkAfterNotificationModes}}
            @value={{this.bookmark.autoDeletePreference}}
            @id="bookmark-after-notification-mode"
          />
          <label>
            <Input
              @type="checkbox"
              @checked={{this.defaultFutureAutoDeletePreference}}
              class="toggle-overridden"
            />
            {{i18n "bookmarks.auto_delete_preference.after_reminder_checkbox"}}
          </label>
        </div>
      </:body>

      <:footer>
        <DButton
          id="save-bookmark"
          @label="bookmarked.title"
          class="btn-primary"
          @action={{this.saveAndClose}}
        />
        <DModalCancel @close={{action "closeWithoutSavingBookmark"}} />
      </:footer>
    </DModal>
  </template>
}

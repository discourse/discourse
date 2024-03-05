import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import BookmarkModal from "discourse/components/modal/bookmark";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";

export default class BookmarkMenu extends Component {
  @service modal;
  @service currentUser;
  @service toasts;
  @tracked quicksaved = false;

  bookmarkManager = this.args.bookmarkManager;
  timeShortcuts = timeShortcuts(this.currentUser.timezone || moment.tz.guess());

  reminderAtOptions = [
    this.timeShortcuts.twoHours(),
    this.timeShortcuts.tomorrow(),
    this.timeShortcuts.threeDays(),
    this.timeShortcuts.custom(),
  ];

  get existingBookmark() {
    return this.bookmarkManager.trackedBookmark.id
      ? this.bookmarkManager.trackedBookmark
      : null;
  }

  get showEditDeleteMenu() {
    return this.existingBookmark && !this.quicksaved;
  }

  @action
  async onBookmark(event) {
    event.target.blur();

    if (this.existingBookmark) {
      return;
    }

    try {
      await this.bookmarkManager.create();
      // We show the menu with Edit/Delete options if the bokmark exists,
      // so this "quicksave" will do nothing in that case.
      // NOTE: Need a nicer way to handle this; otherwise as soon as you save
      // a bookmark, it switches to the other Edit/Delete menu.
      //
      // Also we have the opposite problem -- when closing the DMenu we have
      // no on-close hook, so we can't reset this.
      this.quicksaved = true;

      this.toasts.success({
        duration: 3000,
        data: { message: "Bookmarked!" },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  onCloseMenu() {
    console.log("close");
  }

  @action
  onShowMenu() {
    console.log("show");
  }

  @action
  onEditBookmark() {
    this._openBookmarkModal();
  }

  @action
  onRemoveBookmark() {
    this.bookmarkManager.delete().then(() => {
      this.bookmarkManager.afterDelete();
    });
  }

  @action
  onChooseReminderOption(option) {
    // NOTE: We need to handle here:
    //   * Bookmark already created since we opened the menu, so we are just
    //   updating it with whatever quick option is chosen.
    //   * Same as above, but Custom option is chosen, so we open the modal
    //   for "editing" the bookmark.
    if (option.id === TIME_SHORTCUT_TYPES.CUSTOM) {
      this._openBookmarkModal();
    }
  }

  _openBookmarkModal() {
    this.modal
      .show(BookmarkModal, {
        model: {
          bookmark: this.bookmarkManager.trackedBookmark,
          afterSave: (savedData) => {
            return this.bookmarkManager.afterSave(savedData);
          },
          afterDelete: (topicBookmarked, bookmarkId) => {
            this.bookmarkManager.afterDelete(topicBookmarked, bookmarkId);
          },
        },
      })
      .then((closeData) => {
        this.bookmarkManager.afterModalClose(closeData);
      });
  }

  <template>
    <DMenu
      @identifier="bookmark-menu"
      @triggers={{array "click"}}
      @arrow="true"
      {{on "click" this.onBookmark}}
      class={{concatClass
        "bookmark with-reminder widget-button btn-flat no-text btn-icon bookmark-menu__trigger"
        (if this.existingBookmark "bookmarked")
      }}
      @onClose={{this.onCloseMenu}}
      @onShow={{this.onShowMenu}}
    >
      <:trigger>
        {{#if this.bookmarkManager.trackedBookmark.reminderAt}}
          {{dIcon "discourse-bookmark-clock"}}
        {{else}}
          {{dIcon "bookmark"}}
        {{/if}}
      </:trigger>
      <:content>
        <div class="bookmark-menu__body">
          {{#if this.showEditDeleteMenu}}
            <ul class="bookmark-menu__actions">
              <li class="bookmark-menu__row -edit">
                <DButton
                  @icon="pencil-alt"
                  @translatedLabel="Edit"
                  @action={{this.onEditBookmark}}
                  @class="bookmark-menu__row-btn btn-flat"
                />
              </li>
              <li
                class="bookmark-menu__row -remove"
                role="button"
                tabindex="0"
                {{on "click" this.onRemoveBookmark}}
              >
                <DButton
                  @icon="trash-alt"
                  @translatedLabel="Delete"
                  @action={{this.onRemoveBookmark}}
                  @class="bookmark-menu__row-btn btn-flat"
                />
              </li>
            </ul>
          {{else}}
            <span class="bookmark-menu__row-title">{{i18n
                "bookmarks.also_set_reminder"
              }}</span>
            <ul class="bookmark-menu__actions">
              {{#each this.reminderAtOptions as |option|}}
                <li class={{concatClass "bookmark-menu__row" option.class}}>
                  <DButton
                    @label={{option.label}}
                    @action={{fn this.onChooseReminderOption option}}
                    @class="bookmark-menu__row-btn btn-flat"
                  />
                </li>
              {{/each}}
            </ul>
          {{/if}}
        </div>
      </:content>
    </DMenu>
  </template>
}

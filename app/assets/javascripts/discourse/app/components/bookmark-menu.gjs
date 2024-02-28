import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { BookmarkFormData } from "discourse/lib/bookmark";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";
import BookmarkRedesignModal from "../components/modal/bookmark-redesign";

export default class BookmarkMenu extends Component {
  @service modal;
  @service currentUser;

  bookmarkManager = this.args.bookmarkManager;
  timeShortcuts = timeShortcuts(this.currentUser.timezone || moment.tz.guess());

  reminderAtOptions = [
    this.timeShortcuts.twoHours(),
    this.timeShortcuts.tomorrow(),
    this.timeShortcuts.threeDays(),
    this.timeShortcuts.custom(),
  ];

  get existingBookmark() {
    return this.bookmarkManager.bookmark.id
      ? this.bookmarkManager.bookmark
      : null;
  }

  @action
  onBookmark(event) {
    // eslint-disable-next-line no-console
    console.log("on bookmark");
    event.target.blur();

    if (this.existingBookmark) {
      // this should do nothing if existing...
    } else {
      // handle create bookmark
    }
  }

  @action
  onEditBookmark() {
    // eslint-disable-next-line no-console
    console.log("on edit reminder");

    this._openBookmarkModal();
  }

  @action
  onRemoveBookmark() {
    // eslint-disable-next-line no-console
    console.log("on remove bookmark");
  }

  @action
  onChooseReminderOption(option) {
    // eslint-disable-next-line no-console
    console.log(option);

    if (option.id === TIME_SHORTCUT_TYPES.CUSTOM) {
      this._openBookmarkModal();
    }
  }

  _openBookmarkModal() {
    const bookmark = this.bookmarkManager.bookmark;

    // TODO (martin) Really all this needs to be redone/cleaned up, it's only
    // here to launch the new modal so it can be seen.
    this.modal
      .show(BookmarkRedesignModal, {
        model: {
          bookmark: new BookmarkFormData(bookmark),
          context: this.bookmarkManager.model,
          // TODO: Maybe find a nicer way of doing this -- for post it will be topic title,
          // for chat message it will be channel.
          contextTitle: this.bookmarkManager.contextTitle,
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
        (if this.bookmarkManager.model.bookmarked "-bookmarked")
      }}
    >
      <:trigger>
        {{#if this.bookmarkManager.model.bookmarkReminderAt}}
          {{dIcon "discourse-bookmark-clock"}}
        {{else}}
          {{dIcon "bookmark"}}
        {{/if}}
      </:trigger>
      <:content>
        {{!--
		TODO: This will be a Toast now instead or alternatively reuse the post-copy Link copied! popup
    {{#if this.bookmarkedNotice}}
      <span
        class={{concatClass
          "bookmark-menu__notice"
          (if this.slideOutBookmarkNotice "-slide-out")
        }}
        {{this.scheduleSlideOut}}
        {{this.scheduleRemove}}
      >
        Bookmarked!
      </span>
    {{/if}}
	--}}

        <div class="bookmark-menu__body">
          {{#if this.bookmarkManager.model.bookmarked}}
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

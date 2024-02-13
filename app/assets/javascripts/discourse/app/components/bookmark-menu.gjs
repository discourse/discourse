import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_ESC,
} from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { BookmarkFormData } from "discourse/lib/bookmark";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import Bookmark from "discourse/models/bookmark";
import dIcon from "discourse-common/helpers/d-icon";
import DMenu from "float-kit/components/d-menu";
import BookmarkRedesignModal from "../components/modal/bookmark-redesign";

export default class BookmarkMenu extends Component {
  @service modal;
  @service currentUser;

  @controller("topic") topicController;

  timeShortcuts = timeShortcuts(this.currentUser.timezone || moment.tz.guess());

  reminderAtOptions = [
    this.timeShortcuts.twoHours(),
    this.timeShortcuts.tomorrow(),
    this.timeShortcuts.threeDays(),
    this.timeShortcuts.custom(),
  ];

  get existingBookmark() {
    return this.topicController.model.bookmarks.find(
      (bookmark) =>
        bookmark.bookmarkable_id === this.args.post.id &&
        bookmark.bookmarkable_type === "Post"
    );
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
    // TODO (martin) This will need to be changed when using the bookmark menu
    // with chat.
    const post = this.args.post;
    const bookmark =
      this.existingBookmark ||
      Bookmark.createFor(this.currentUser, "Post", post.id);

    // TODO (martin) Really all this needs to be redone/cleaned up, it's only
    // here to launch the new modal so it can be seen.
    this.modal
      .show(BookmarkRedesignModal, {
        model: {
          bookmark: new BookmarkFormData(bookmark),
          context: post,
          afterSave: (savedData) => {
            this._syncBookmarks(savedData);
            this.model.set("bookmarking", false);
            post.createBookmark(savedData);
            this.model.afterPostBookmarked(post, savedData);
            return [post.id];
          },
          afterDelete: (topicBookmarked, bookmarkId) => {
            this.model.removeBookmark(bookmarkId);
            post.deleteBookmark(topicBookmarked);
          },
        },
      })
      .then((closeData) => {
        if (!closeData) {
          return;
        }

        if (
          closeData.closeWithoutSaving ||
          closeData.initiatedBy === CLOSE_INITIATED_BY_ESC ||
          closeData.initiatedBy === CLOSE_INITIATED_BY_BUTTON
        ) {
          post.appEvents.trigger("post-stream:refresh", {
            id: bookmark.bookmarkable_id,
          });
        }
      });
  }

  <template>
    <DMenu
      @triggers={{array "click"}}
      @arrow="true"
      {{on "click" this.onBookmark}}
      class={{concatClass
        "bookmark with-reminder widget-button btn-flat no-text btn-icon bookmark-menu__trigger"
        (if @post.bookmarked "-bookmarked")
      }}
    >
      <:trigger>
        {{#if @post.bookmarkReminderAt}}
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
          {{#if @post.bookmarked}}
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
            <span class="bookmark-menu__row-title">Also set a reminder?</span>
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

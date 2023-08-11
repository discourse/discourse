import { later } from "@ember/runloop";
import {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_ESC,
} from "discourse/components/d-modal";
import { getOwner } from "discourse-common/lib/get-owner";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Bookmark from "discourse/models/bookmark";
import { BookmarkFormData } from "discourse/lib/bookmark";
import BookmarkRedesignModal from "../components/modal/bookmark-redesign";

export default class DiscourseBookmarkMenu extends Component {
  @service modal;
  @service currentUser;

  // TODO Replace these (except none/custom) with time shortcuts from time-shortcut
  reminderAtOptions = [
    { id: 1, name: "In two hours" },
    { id: 2, name: "Tomorrow" },
    { id: 3, name: "In three days" },
    { id: 4, name: "Custom..." },
    { id: 5, name: "No reminder", class: "-no-reminder", autofocus: true },
  ];

  @action
  autoFocusButton(option, target) {
    later(() => {
      if (option.autofocus) {
        target.focus();
      }
    }, 500);
  }

  @action
  onBookmark() {
    // eslint-disable-next-line no-console
    console.log("on bookmark");
  }

  @action
  onEditReminder() {
    // eslint-disable-next-line no-console
    console.log("on edit reminder");
  }

  @action
  onRemoveBookmark() {
    // eslint-disable-next-line no-console
    console.log("on remove bookmark");
  }

  @action
  onChooseOption(option) {
    // eslint-disable-next-line no-console
    console.log(option);

    if (option.id === 4) {
      this._openBookmarkModal();
    }
  }

  _openBookmarkModal() {
    // TODO (martin) This will need to be changed when using the bookmark menu
    // with chat.
    const post = this.args.post;
    const topicController = getOwner(this).lookup("controller:topic");
    const bookmarkForPost = topicController.model.bookmarks.find(
      (bookmark) =>
        bookmark.bookmarkable_id === post.id &&
        bookmark.bookmarkable_type === "Post"
    );
    const bookmark =
      bookmarkForPost || Bookmark.createFor(this.currentUser, "Post", post.id);

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
}

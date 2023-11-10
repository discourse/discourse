import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_ESC,
} from "discourse/components/d-modal";
import { BookmarkFormData } from "discourse/lib/bookmark";
import Bookmark from "discourse/models/bookmark";
import discourseLater from "discourse-common/lib/later";
import BookmarkRedesignModal from "../components/modal/bookmark-redesign";

export default class DiscourseBookmarkMenu extends Component {
  @service modal;
  @service currentUser;

  @controller("topic") topicController;

  @tracked bookmarkedNotice = false;
  @tracked slideOutBookmarkNotice = false;

  scheduleSlideOut = modifier(() => {
    const handler = discourseLater(() => {
      this.slideOutBookmarkNotice = true;
    }, 1000);

    return () => {
      cancel(handler);
    };
  });

  scheduleRemove = modifier(() => {
    const handler = discourseLater(() => {
      this.bookmarkedNotice = false;
    }, 2500);

    return () => {
      cancel(handler);
    };
  });

  // TODO Replace these (except none/custom) with time shortcuts from time-shortcut
  reminderAtOptions = [
    { id: 1, name: "In two hours" },
    { id: 2, name: "Tomorrow" },
    { id: 3, name: "in three days" },
    { id: 4, name: "Custom..." },
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
      // handle remove bookmark, maybe?
    } else {
      this.slideOutBookmarkNotice = false;
      this.bookmarkedNotice = true;
    }
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
}

import { setOwner } from "@ember/application";
import { inject as controller } from "@ember/controller";
import { inject as service } from "@ember/service";
import {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_ESC,
} from "discourse/components/d-modal";
import Bookmark from "discourse/models/bookmark";

export default class PostBookmarkManager {
  @service currentUser;
  @controller("topic") topicController;

  constructor(owner, post) {
    setOwner(this, owner);

    this.post = post;

    this.bookmark =
      this.topicController.model.bookmarks.find(
        (bookmark) =>
          bookmark.bookmarkable_id === this.post.id &&
          bookmark.bookmarkable_type === "Post"
      ) || Bookmark.createFor(this.currentUser, "Post", this.post.id);
  }

  get model() {
    return this.post;
  }

  get contextTitle() {
    return this.model.topic.title;
  }

  afterModalClose(closeData) {
    if (!closeData) {
      return;
    }

    if (
      closeData.closeWithoutSaving ||
      closeData.initiatedBy === CLOSE_INITIATED_BY_ESC ||
      closeData.initiatedBy === CLOSE_INITIATED_BY_BUTTON
    ) {
      this.post.appEvents.trigger("post-stream:refresh", {
        id: this.post.id,
      });
    }
  }

  afterSave(savedData) {
    this._syncBookmarks(savedData);
    this.topicController.model.set("bookmarking", false);
    this.post.createBookmark(savedData);
    this.topicController.model.afterPostBookmarked(this.post, savedData);
    return [this.post.id];
  }

  afterDelete(topicBookmarked, bookmarkId) {
    this.topicController.model.removeBookmark(bookmarkId);
    this.post.deleteBookmark(topicBookmarked);
  }

  _syncBookmarks(data) {
    if (!this.topicController.bookmarks) {
      this.topicController.set("bookmarks", []);
    }

    const bookmark = this.topicController.bookmarks.findBy("id", data.id);
    if (!bookmark) {
      this.topicController.bookmarks.pushObject(Bookmark.create(data));
    } else {
      bookmark.reminder_at = data.reminder_at;
      bookmark.name = data.name;
      bookmark.auto_delete_preference = data.auto_delete_preference;
    }
  }
}

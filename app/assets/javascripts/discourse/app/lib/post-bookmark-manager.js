import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_ESC,
} from "discourse/components/d-modal";
import { BookmarkFormData } from "discourse/lib/bookmark-form-data";
import Bookmark from "discourse/models/bookmark";

export default class PostBookmarkManager {
  @service currentUser;
  @service bookmarkApi;
  @service appEvents;
  @controller("topic") topicController;

  @tracked trackedBookmark;
  @tracked bookmarkModel;

  constructor(owner, post) {
    setOwner(this, owner);

    this.model = post;
    this.type = "Post";

    this.bookmarkModel =
      this.topicController.model?.bookmarks.find(
        (bookmark) =>
          bookmark.bookmarkable_id === this.model.id &&
          bookmark.bookmarkable_type === this.type
      ) || this.bookmarkApi.buildNewBookmark(this.type, this.model.id);
    this.reset();
  }

  reset() {
    this.trackedBookmark = new BookmarkFormData(this.bookmarkModel);
  }

  create() {
    return this.bookmarkApi
      .create(this.trackedBookmark)
      .then((updatedBookmark) => {
        this.trackedBookmark = updatedBookmark;
        this._syncBookmarks(updatedBookmark.saveData);
        return this.trackedBookmark;
      });
  }

  delete() {
    return this.bookmarkApi
      .delete(this.trackedBookmark.id)
      .then((deleteResponse) => {
        this.topicController.model.removeBookmark(this.trackedBookmark.id);
        return deleteResponse;
      });
  }

  save() {
    return this.bookmarkApi.update(this.trackedBookmark).then(() => {
      this._syncBookmarks(this.trackedBookmark.saveData);
      return this.trackedBookmark;
    });
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
      this.appEvents.trigger("post-stream:refresh", {
        id: this.model.id,
      });
    }
  }

  afterSave(bookmarkFormData) {
    this.trackedBookmark = bookmarkFormData;
    this._syncBookmarks(bookmarkFormData.saveData);
    this.topicController.model.set("bookmarking", false);
    this.topicController.model.incrementProperty("bookmarksWereChanged");
    this.model.createBookmark(bookmarkFormData.saveData);
    this.topicController.model.afterPostBookmarked(
      this.model,
      bookmarkFormData.saveData
    );
    return [this.model.id];
  }

  afterDelete(deleteResponse, bookmarkId) {
    this.topicController.model.removeBookmark(bookmarkId);
    this.model.deleteBookmark(deleteResponse.topic_bookmarked);
    this.bookmarkModel = this.bookmarkApi.buildNewBookmark(
      this.type,
      this.model.id
    );
    this.trackedBookmark = new BookmarkFormData(this.bookmarkModel);
  }

  _syncBookmarks(data) {
    if (!this.topicController.model.bookmarks) {
      this.topicController.model.set("bookmarks", []);
    }

    const bookmark = this.topicController.model.bookmarks.findBy("id", data.id);
    if (!bookmark) {
      this.topicController.model.bookmarks.pushObject(Bookmark.create(data));
      this.topicController.model.incrementProperty("bookmarksWereChanged");
    } else {
      bookmark.reminder_at = data.reminder_at;
      bookmark.name = data.name;
      bookmark.auto_delete_preference = data.auto_delete_preference;
    }
  }
}

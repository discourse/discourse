import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { BookmarkFormData } from "discourse/lib/bookmark-form-data";
import Bookmark from "discourse/models/bookmark";

export default class TopicBookmarkManager {
  @service currentUser;
  @service bookmarkApi;
  @controller("topic") topicController;

  @tracked trackedBookmark;
  @tracked bookmarkModel;

  constructor(owner, topic) {
    setOwner(this, owner);

    this.model = topic;
    this.type = "Topic";

    this.bookmarkModel =
      this.topicController.model?.bookmarks.find(
        (bookmark) =>
          bookmark.bookmarkable_id === this.model.id &&
          bookmark.bookmarkable_type === this.type
      ) || this.bookmarkApi.buildNewBookmark(this.type, this.model.id);
    this.trackedBookmark = new BookmarkFormData(this.bookmarkModel);
  }

  create() {
    return this.bookmarkApi
      .create(this.trackedBookmark)
      .then((updatedBookmark) => {
        this.trackedBookmark = updatedBookmark;
      });
  }

  delete() {
    return this.bookmarkApi.delete(this.trackedBookmark.id);
  }

  save() {
    return this.bookmarkApi.update(this.trackedBookmark);
  }

  // noop for topics
  afterModalClose() {
    return;
  }

  afterSave(bookmarkFormData) {
    this.trackedBookmark = bookmarkFormData;
    this._syncBookmarks(bookmarkFormData.saveData);
    this.topicController.model.set("bookmarking", false);
    this.topicController.model.set("bookmarked", true);
    this.topicController.model.incrementProperty("bookmarksWereChanged");
    this.topicController.model.appEvents.trigger(
      "bookmarks:changed",
      bookmarkFormData.saveData,
      this.bookmarkModel.attachedTo()
    );
    return [this.model.id];
  }

  afterDelete(deleteResponse, bookmarkId) {
    this.topicController.model.removeBookmark(bookmarkId);
    this.bookmarkModel = this.bookmarkApi.buildNewBookmark(
      this.type,
      this.model.id
    );
    this.trackedBookmark = new BookmarkFormData(this.bookmarkModel);
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

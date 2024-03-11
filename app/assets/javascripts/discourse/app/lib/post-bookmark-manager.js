import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/application";
import { inject as controller } from "@ember/controller";
import { inject as service } from "@ember/service";
import {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_ESC,
} from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { BookmarkFormData } from "discourse/lib/bookmark";
import Bookmark from "discourse/models/bookmark";

export default class PostBookmarkManager {
  @service currentUser;
  @controller("topic") topicController;
  @tracked trackedBookmark;

  constructor(owner, post) {
    setOwner(this, owner);

    this.model = post;
    this.type = "Post";

    // NOTE: (martin) Not sure about this double-up of the bookmark with
    // BookmarkFormData...but the latter is necessary because it allows
    // @tracked and doen't deal with the RestModel nonsense. Will think...
    this.bookmark =
      this.topicController.model.bookmarks.find(
        (bookmark) =>
          bookmark.bookmarkable_id === this.model.id &&
          bookmark.bookmarkable_type === this.type
      ) || this._createEmptyBookmark();
    this.trackedBookmark = new BookmarkFormData(this.bookmark);
  }

  get contextTitle() {
    return this.model.topic.title;
  }

  // TODO (martin): Likely move this to some service.
  create() {
    return ajax("/bookmarks.json", {
      method: "POST",
      data: {
        bookmarkable_id: this.model.id,
        bookmarkable_type: this.type,
      },
    })
      .then((response) => {
        this.trackedBookmark.id = response.id;
        return this.trackedBookmark.id;
      })
      .catch(popupAjaxError);
  }

  // TODO (martin): Likely move this to some service.
  delete() {
    return ajax(`/bookmarks/${this.trackedBookmark.id}.json`, {
      method: "DELETE",
    }).catch(popupAjaxError);
  }

  // TODO (martin): Likely move this to some service.
  update(data) {
    return ajax(`/bookmarks/${this.trackedBookmark.id}.json`, {
      method: "PUT",
      data: {
        reminder_at: data.reminder_at,
      },
    }).catch(popupAjaxError);
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
      this.model.appEvents.trigger("post-stream:refresh", {
        id: this.model.id,
      });
    }
  }

  afterSave(savedData) {
    this._syncBookmarks(savedData);
    this.topicController.model.set("bookmarking", false);
    this.model.createBookmark(savedData);
    this.topicController.model.afterPostBookmarked(this.model, savedData);
    return [this.model.id];
  }

  afterDelete(topicBookmarked, bookmarkId) {
    this.topicController.model.removeBookmark(bookmarkId);
    this.model.deleteBookmark(topicBookmarked);
    this.bookmark = this._createEmptyBookmark();
    this.trackedBookmark = new BookmarkFormData(this.bookmark);
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

  _createEmptyBookmark() {
    return Bookmark.createFor(this.currentUser, this.type, this.model.id);
  }
}

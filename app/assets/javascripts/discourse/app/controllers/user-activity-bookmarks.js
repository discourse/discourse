import I18n from "I18n";
import Controller from "@ember/controller";
import showModal from "discourse/lib/show-modal";
import { Promise } from "rsvp";
import { inject } from "@ember/controller";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import Bookmark from "discourse/models/bookmark";

export default Controller.extend({
  application: inject(),
  user: inject(),

  content: null,
  loading: false,
  noResultsHelp: null,

  loadItems() {
    this.setProperties({
      content: [],
      loading: true,
      noResultsHelp: null
    });

    return this.model
      .loadItems()
      .then(response => this._processLoadResponse(response))
      .catch(() => this._bookmarksListDenied())
      .finally(() =>
        this.setProperties({
          loaded: true,
          loading: false
        })
      );
  },

  @discourseComputed("loaded", "content.length", "noResultsHelp")
  noContent(loaded, contentLength, noResultsHelp) {
    return loaded && contentLength === 0 && noResultsHelp;
  },

  _removeBookmarkFromList(bookmark) {
    this.content.removeObject(bookmark);
  },

  @action
  removeBookmark(bookmark) {
    const deleteBookmark = () => {
      return bookmark
        .destroy()
        .then(() => this._removeBookmarkFromList(bookmark));
    };
    if (!bookmark.reminder_at) {
      return deleteBookmark();
    }
    bootbox.confirm(I18n.t("bookmarks.confirm_delete"), result => {
      if (result) {
        return deleteBookmark();
      }
    });
  },

  @action
  editBookmark(bookmark) {
    let controller = showModal("bookmark", {
      model: {
        postId: bookmark.post_id,
        id: bookmark.id,
        reminderAt: bookmark.reminder_at,
        name: bookmark.name
      },
      title: "post.bookmarks.edit",
      modalClass: "bookmark-with-reminder"
    });
    controller.setProperties({
      afterSave: () => this.loadItems()
    });
  },

  @action
  loadMore() {
    if (this.loadingMore) {
      return Promise.resolve();
    }

    this.set("loadingMore", true);

    return this.model
      .loadMore()
      .then(response => this._processLoadResponse(response))
      .catch(() => this._bookmarksListDenied())
      .finally(() => this.set("loadingMore", false));
  },

  _bookmarksListDenied() {
    this.set("noResultsHelp", I18n.t("bookmarks.list_permission_denied"));
  },

  _processLoadResponse(response) {
    if (!response) {
      this._bookmarksListDenied();
      return;
    }

    if (response.no_results_help) {
      this.set("noResultsHelp", response.no_results_help);
      return;
    }

    response = response.user_bookmark_list;
    this.model.more_bookmarks_url = response.more_bookmarks_url;

    if (response.bookmarks) {
      this.content.pushObjects(
        response.bookmarks.map(bookmark => Bookmark.create(bookmark))
      );
    }
  }
});

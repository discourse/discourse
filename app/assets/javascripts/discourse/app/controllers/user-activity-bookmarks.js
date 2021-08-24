import Controller, { inject as controller } from "@ember/controller";
import { iconHTML } from "discourse-common/lib/icon-library";
import Bookmark from "discourse/models/bookmark";
import I18n from "I18n";
import { Promise } from "rsvp";
import EmberObject, { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { notEmpty } from "@ember/object/computed";

export default Controller.extend({
  queryParams: ["q"],

  application: controller(),
  user: controller(),

  content: null,
  loading: false,
  permissionDenied: false,
  searchTerm: null,
  q: null,
  inSearchMode: notEmpty("q"),

  loadItems() {
    this.setProperties({
      content: [],
      loading: true,
      permissionDenied: false,
      searchTerm: this.q,
    });

    return this.model
      .loadItems({ q: this.q })
      .then((response) => this._processLoadResponse(response))
      .catch(() => this._bookmarksListDenied())
      .finally(() => {
        this.setProperties({
          loaded: true,
          loading: false,
        });
      });
  },

  @discourseComputed()
  emptyStateBody() {
    return I18n.t("user.no_bookmarks_body", {
      icon: iconHTML("bookmark"),
    }).htmlSafe();
  },

  @discourseComputed("inSearchMode", "noContent")
  userDoesNotHaveBookmarks(inSearchMode, noContent) {
    return !inSearchMode && noContent;
  },

  @discourseComputed("inSearchMode", "noContent")
  nothingFound(inSearchMode, noContent) {
    return inSearchMode && noContent;
  },

  @discourseComputed("loaded", "content.length")
  noContent(loaded, contentLength) {
    return loaded && contentLength === 0;
  },

  @action
  search() {
    this.set("q", this.searchTerm);
    this.loadItems();
  },

  @action
  reload() {
    this.loadItems();
  },

  @action
  loadMore() {
    if (this.loadingMore) {
      return Promise.resolve();
    }

    this.set("loadingMore", true);

    return this.model
      .loadMore({ q: this.q })
      .then((response) => this._processLoadResponse(response))
      .catch(() => this._bookmarksListDenied())
      .finally(() => this.set("loadingMore", false));
  },

  _bookmarksListDenied() {
    this.set("permissionDenied", true);
  },

  _processLoadResponse(response) {
    if (!response || !response.user_bookmark_list) {
      return;
    }

    response = response.user_bookmark_list;
    this.model.more_bookmarks_url = response.more_bookmarks_url;

    if (response.bookmarks) {
      const bookmarkModels = response.bookmarks.map((bookmark) => {
        const bookmarkModel = Bookmark.create(bookmark);
        bookmarkModel.topicStatus = EmberObject.create({
          closed: bookmark.closed,
          archived: bookmark.archived,
          is_warning: bookmark.is_warning,
          pinned: false,
          unpinned: false,
          invisible: bookmark.invisible,
        });
        return bookmarkModel;
      });
      this.content.pushObjects(bookmarkModels);
    }
  },
});

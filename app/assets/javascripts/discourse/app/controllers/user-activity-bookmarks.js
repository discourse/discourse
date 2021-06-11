import Controller, { inject as controller } from "@ember/controller";
import Bookmark from "discourse/models/bookmark";
import I18n from "I18n";
import { Promise } from "rsvp";
import EmberObject, { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  application: controller(),
  user: controller(),

  content: null,
  loading: false,
  noResultsHelp: null,
  searchTerm: null,
  q: null,

  queryParams: ["q"],

  loadItems() {
    this.setProperties({
      content: [],
      loading: true,
      noResultsHelp: null,
    });

    if (this.q && !this.searchTerm) {
      this.set("searchTerm", this.q);
    }

    return this.model
      .loadItems({ q: this.searchTerm })
      .then((response) => this._processLoadResponse(response))
      .catch(() => this._bookmarksListDenied())
      .finally(() => {
        this.setProperties({
          loaded: true,
          loading: false,
        });
      });
  },

  @discourseComputed("loaded", "content.length")
  noContent(loaded, contentLength) {
    return loaded && contentLength === 0;
  },

  @discourseComputed("noResultsHelp", "noContent")
  noResultsHelpMessage(noResultsHelp, noContent) {
    if (noResultsHelp) {
      return noResultsHelp;
    }
    if (noContent) {
      return I18n.t("bookmarks.no_user_bookmarks");
    }
    return "";
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
      .loadMore({ q: this.searchTerm })
      .then((response) => this._processLoadResponse(response))
      .catch(() => this._bookmarksListDenied())
      .finally(() => this.set("loadingMore", false));
  },

  _bookmarksListDenied() {
    this.set("noResultsHelp", I18n.t("bookmarks.list_permission_denied"));
  },

  _processLoadResponse(response) {
    if (!response) {
      return;
    }

    if (response.no_results_help) {
      this.set("noResultsHelp", response.no_results_help);
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

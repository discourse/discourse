import Controller from "@ember/controller";
import { inject } from "@ember/controller";
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
      .then(response => {
        if (response && response.no_results_help) {
          this.set("noResultsHelp", response.no_results_help);
        }

        if (response && response.bookmarks) {
          let bookmarks = [];
          response.bookmarks.forEach(bookmark => {
            bookmarks.push(Bookmark.create(bookmark));
          });
          this.content.pushObjects(bookmarks);
        }
      })
      .catch(() => {
        this.set("noResultsHelp", I18n.t("bookmarks.list_permission_denied"));
      })
      .finally(() =>
        this.setProperties({
          loaded: true,
          loading: false
        })
      );
  },

  @discourseComputed("loaded", "content.length")
  noContent(loaded, contentLength) {
    return loaded && contentLength === 0;
  },

  actions: {
    removeBookmark(bookmark) {
      return bookmark.destroy().then(() => this.loadItems());
    }
  }
});

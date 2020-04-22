import Controller from "@ember/controller";
import showModal from "discourse/lib/show-modal";
import { Promise } from "rsvp";
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
        this.processLoadResponse(response);
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

  @discourseComputed("loaded", "content.length", "noResultsHelp")
  noContent(loaded, contentLength, noResultsHelp) {
    return loaded && contentLength === 0 && noResultsHelp !== null;
  },

  processLoadResponse(response) {
    response = response.user_bookmark_list;

    if (response && response.no_results_help) {
      this.set("noResultsHelp", response.no_results_help);
    }

    this.model.more_bookmarks_url = response.more_bookmarks_url;

    if (response && response.bookmarks) {
      let bookmarks = [];
      response.bookmarks.forEach(bookmark => {
        bookmarks.push(Bookmark.create(bookmark));
      });
      this.content.pushObjects(bookmarks);
    }
  },

  actions: {
    removeBookmark(bookmark) {
      bootbox.confirm(I18n.t("bookmarks.confirm_delete"), result => {
        if (result) {
          return bookmark.destroy().then(() => this.loadItems());
        }
      });
    },

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

    loadMore() {
      if (this.loadingMore) {
        return Promise.resolve();
      }
      this.set("loadingMore", true);

      return this.model
        .loadMore()
        .then(response => this.processLoadResponse(response))
        .catch(() => {
          this.set("noResultsHelp", I18n.t("bookmarks.list_permission_denied"));
        })
        .finally(() =>
          this.setProperties({
            loadingMore: false
          })
        );
    }
  }
});

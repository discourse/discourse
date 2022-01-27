import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { Promise } from "rsvp";

export default DiscourseRoute.extend({
  queryParams: {
    acting_username: { refreshModel: true },
    q: { refreshModel: true },
  },

  model(params, transition) {
    const controller = this.controllerFor("user-activity-bookmarks");

    if (this.isPoppedState(transition) && this.session.bookmarksModel) {
      return Promise.resolve(this.session.bookmarksModel);
    }

    this.session.setProperties({
      bookmarksModel: null,
      bookmarkListScrollPosition: null,
    });

    return this._loadBookmarks(params)
      .then((response) => {
        if (!response.user_bookmark_list) {
          return { bookmarks: [] };
        }

        const bookmarks = response.user_bookmark_list.bookmarks.map(
          controller.transform
        );
        const loadMoreUrl = response.user_bookmark_list.more_bookmarks_url;

        const model = { bookmarks, loadMoreUrl };
        this.session.set("bookmarksModel", model);
        return model;
      })
      .catch(() => controller.set("permissionDenied", true));
  },

  renderTemplate() {
    this.render("user_bookmarks");
  },

  @action
  didTransition() {
    this.controllerFor("user-activity")._showFooter();
    return true;
  },

  @action
  loading(transition) {
    let controller = this.controllerFor("user-activity-bookmarks");
    controller.set("loading", true);
    transition.promise.finally(function () {
      controller.set("loading", false);
    });
  },

  @action
  triggerRefresh() {
    this.refresh();
  },

  _loadBookmarks(params) {
    let url = `/u/${this.modelFor("user").username}/bookmarks.json`;

    if (params) {
      url += "?" + $.param(params);
    }

    return ajax(url);
  },
});

import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { Promise } from "rsvp";
import I18n from "I18n";

export default DiscourseRoute.extend({
  templateName: "user/bookmarks",

  queryParams: {
    acting_username: { refreshModel: true },
    q: { refreshModel: true },
  },

  model(params, transition) {
    const controller = this.controllerFor("user-activity-bookmarks");

    if (
      this.isPoppedState(transition) &&
      this.session.bookmarksModel &&
      this.session.bookmarksModel.searchTerm === params.q
    ) {
      return Promise.resolve(this.session.bookmarksModel);
    }

    this.session.setProperties({
      bookmarksModel: null,
    });

    controller.set("loading", true);

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
      .catch(() => controller.set("permissionDenied", true))
      .finally(() => controller.set("loading", false));
  },

  titleToken() {
    return I18n.t("user_action_groups.3");
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

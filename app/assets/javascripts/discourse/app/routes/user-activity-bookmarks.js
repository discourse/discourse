import { action } from "@ember/object";
import { service } from "@ember/service";
import $ from "jquery";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import Bookmark from "discourse/models/bookmark";
import Site from "discourse/models/site";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserActivityBookmarks extends DiscourseRoute {
  @service historyStore;

  templateName = "user/bookmarks";

  queryParams = {
    acting_username: { refreshModel: true },
    q: { refreshModel: true },
  };

  model(params) {
    const controller = this.controllerFor("user-activity-bookmarks");

    if (
      this.historyStore.isPoppedState &&
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
      .then(async (response) => {
        if (!response.user_bookmark_list) {
          return { bookmarks: [] };
        }

        response.user_bookmark_list.categories?.forEach((category) =>
          Site.current().updateCategory(category)
        );

        const bookmarks = response.user_bookmark_list.bookmarks.map(
          controller.transform
        );
        await Bookmark.applyTransformations(bookmarks);
        const loadMoreUrl = response.user_bookmark_list.more_bookmarks_url;

        const model = { bookmarks, loadMoreUrl };
        this.session.set("bookmarksModel", model);
        return model;
      })
      .catch(() => controller.set("permissionDenied", true))
      .finally(() => controller.set("loading", false));
  }

  titleToken() {
    return i18n("user_action_groups.3");
  }

  @action
  triggerRefresh() {
    this.refresh();
  }

  _loadBookmarks(params) {
    let url = `/u/${this.modelFor("user").username}/bookmarks.json`;

    if (params) {
      url += "?" + $.param(params);
    }

    return ajax(url);
  }
}

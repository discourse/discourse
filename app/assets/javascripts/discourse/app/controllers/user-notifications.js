import Controller, { inject as controller } from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { iconHTML } from "discourse-common/lib/icon-library";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";

export default Controller.extend({
  application: controller(),
  queryParams: ["filter"],
  filter: "all",

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  @discourseComputed("filter")
  isFiltered() {
    return this.filter && this.filter !== "all";
  },

  @discourseComputed("model.content.@each.read")
  allNotificationsRead() {
    return !this.get("model.content").some(
      (notification) => !notification.get("read")
    );
  },

  @discourseComputed("isFiltered", "model.content.length")
  doesNotHaveNotifications(isFiltered, contentLength) {
    return !isFiltered && contentLength === 0;
  },

  @discourseComputed("isFiltered", "model.content.length")
  nothingFound(isFiltered, contentLength) {
    return isFiltered && contentLength === 0;
  },

  @discourseComputed()
  emptyStateBody() {
    return I18n.t("user.no_notifications_page_body", {
      preferencesUrl: getURL("/my/preferences/notifications"),
      icon: iconHTML("bell"),
    }).htmlSafe();
  },

  actions: {
    resetNew() {
      ajax("/notifications/mark-read", { type: "PUT" }).then(() => {
        this.model.forEach((n) => n.set("read", true));
      });
    },

    loadMore() {
      this.model.loadMore();
    },
  },
});

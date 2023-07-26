import Controller, { inject as controller } from "@ember/controller";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";
import DismissNotificationConfirmationModal from "discourse/components/modal/dismiss-notification-confirmation";

export default Controller.extend({
  modal: service(),
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
    return htmlSafe(
      I18n.t("user.no_notifications_page_body", {
        preferencesUrl: getURL("/my/preferences/notifications"),
        icon: iconHTML("bell"),
      })
    );
  },

  async markRead() {
    await ajax("/notifications/mark-read", { type: "PUT" });
    this.model.forEach((n) => n.set("read", true));
  },

  actions: {
    async resetNew() {
      if (this.currentUser.unread_high_priority_notifications > 0) {
        this.modal.show(DismissNotificationConfirmationModal, {
          model: {
            confirmationMessage: I18n.t(
              "notifications.dismiss_confirmation.body.default",
              {
                count: this.currentUser.unread_high_priority_notifications,
              }
            ),
            dismissNotifications: () => this.markRead(),
          },
        });
      } else {
        this.markRead();
      }
    },

    loadMore() {
      this.model.loadMore();
    },
  },
});

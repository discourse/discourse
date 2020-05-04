import Controller, { inject as controller } from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { readOnly } from "@ember/object/computed";
import { inject as service } from "@ember/service";

export default Controller.extend({
  application: controller(),
  router: service(),
  currentPath: readOnly("router._router.currentPath"),
  filter: "all",

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  @discourseComputed("model.content.length", "filter")
  hasFilteredNotifications(length, filter) {
    if (filter === "read") {
      return this.model.filterBy("read", true).length > 0;
    } else if (filter === "unread") {
      return this.model.filterBy("read", false).length > 0;
    }
    return length > 0;
  },

  @discourseComputed("model.content.@each.read")
  allNotificationsRead() {
    return !this.get("model.content").some(
      notification => !notification.get("read")
    );
  },

  actions: {
    resetNew() {
      ajax("/notifications/mark-read", { type: "PUT" }).then(() => {
        this.model.forEach(n => n.set("read", true));
      });
    },

    loadMore() {
      this.model.loadMore();
    },

    filterNotifications(value) {
      this.set("filter", value);
    }
  }
});

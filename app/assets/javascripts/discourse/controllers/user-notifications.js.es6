import { ajax } from "discourse/lib/ajax";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  @computed("model.content.length")
  hasNotifications(length) {
    return length > 0;
  },

  @computed("model.content.@each.read")
  allNotificationsRead() {
    return !this.get("model.content").some(
      notification => !notification.get("read")
    );
  },

  actions: {
    resetNew() {
      ajax("/notifications/mark-read", { method: "PUT" }).then(() => {
        this.get("model").forEach(n => n.set("read", true));
      });
    },

    loadMore() {
      this.get("model").loadMore();
    }
  }
});

import { inject } from '@ember/controller';
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  application: inject(),

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
        this.model.forEach(n => n.set("read", true));
      });
    },

    loadMore() {
      this.model.loadMore();
    }
  }
});

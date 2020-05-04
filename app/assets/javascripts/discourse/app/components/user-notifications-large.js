import MountWidget from "discourse/components/mount-widget";
import { observes } from "discourse-common/utils/decorators";

export default MountWidget.extend({
  widget: "user-notifications-large",
  notifications: null,
  filter: null,
  args: null,

  init() {
    this._super(...arguments);

    this.args = { notifications: this.notifications, filter: this.filter };
  },

  @observes("notifications.length", "notifications.@each.read", "filter")
  _triggerRefresh() {
    this.set("args", {
      notifications: this.notifications,
      filter: this.filter
    });

    this.queueRerender();
  }
});

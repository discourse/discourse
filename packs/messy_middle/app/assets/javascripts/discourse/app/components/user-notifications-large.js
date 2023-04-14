import MountWidget from "discourse/components/mount-widget";
import { observes } from "discourse-common/utils/decorators";

export default MountWidget.extend({
  widget: "user-notifications-large",
  notifications: null,
  args: null,

  init() {
    this._super(...arguments);

    this.args = { notifications: this.notifications };
  },

  @observes("notifications.length", "notifications.@each.read")
  _triggerRefresh() {
    this.set("args", {
      notifications: this.notifications,
    });

    this.queueRerender();
  },
});

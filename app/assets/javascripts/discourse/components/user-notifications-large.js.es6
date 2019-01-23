import MountWidget from "discourse/components/mount-widget";
import { observes } from "ember-addons/ember-computed-decorators";

export default MountWidget.extend({
  widget: "user-notifications-large",

  init() {
    this._super(...arguments);
    this.args = { notifications: this.get("notifications") };
  },

  @observes("notifications.length", "notifications.@each.read")
  _triggerRefresh() {
    this.queueRerender();
  }
});

import MountWidget from "discourse/components/mount-widget";
import { observes } from "discourse-common/utils/decorators";

export default MountWidget.extend({
  widget: "user-notifications-large",

  init() {
    this._super(...arguments);
    this.args = { notifications: this.notifications ,filters:this.filters };
  },

  @observes("notifications.length", "notifications.@each.read", "filters")
  _triggerRefresh() {
    this.set('args',{ notifications: this.notifications ,filters:this.filters });
    this.queueRerender();
  }
});

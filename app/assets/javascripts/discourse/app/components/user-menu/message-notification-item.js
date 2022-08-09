import GlimmerComponent from "discourse/components/glimmer";
import Notification from "discourse/models/notification";

export default class UserMenuMessageNotificationItem extends GlimmerComponent {
  get component() {
    if (this.args.item.constructor === Notification) {
      return "user-menu/notification-item";
    } else {
      return "user-menu/message-item";
    }
  }
}

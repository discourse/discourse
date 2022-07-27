import UserMenuNotificationItem from "discourse/components/user-menu/notification-item";
import I18n from "I18n";

export default class UserMenuCustomNotificationItem extends UserMenuNotificationItem {
  get linkTitle() {
    if (this.notification.data.title) {
      return I18n.t(this.notification.data.title);
    }
    return super.linkTitle;
  }

  get icon() {
    return `notification.${this.notification.data.message}`;
  }
}

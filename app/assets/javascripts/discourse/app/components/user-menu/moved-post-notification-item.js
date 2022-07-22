import UserMenuNotificationItem from "discourse/components/user-menu/notification-item";
import I18n from "I18n";

export default class UserMenuMovedPostNotificationItem extends UserMenuNotificationItem {
  get label() {
    return I18n.t("notifications.user_moved_post", { username: this.username });
  }
}

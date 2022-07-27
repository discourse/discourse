import UserMenuNotificationItem from "discourse/components/user-menu/notification-item";
import I18n from "I18n";

export default class UserMenuWatchingFirstPostNotificationItem extends UserMenuNotificationItem {
  get label() {
    return I18n.t("notifications.watching_first_post_label");
  }
}

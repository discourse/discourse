import UserMenuNotificationItem from "discourse/components/user-menu/notification-item";
import I18n from "I18n";

export default class UserMenuBookmarkReminderNotificationItem extends UserMenuNotificationItem {
  get linkTitle() {
    if (this.notification.data.bookmark_name) {
      return I18n.t("notifications.titles.bookmark_reminder_with_name", {
        name: this.notification.data.bookmark_name,
      });
    }
    return super.linkTitle;
  }

  get description() {
    return super.description || this.notification.data.title;
  }
}

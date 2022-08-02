import UserMenuNotificationItem from "discourse/components/user-menu/notification-item";
import I18n from "I18n";

export default class UserMenuGroupMessageSummaryNotificationItem extends UserMenuNotificationItem {
  get inboxCount() {
    return this.notification.data.inbox_count;
  }

  get label() {
    return I18n.t("notifications.group_message_summary", {
      count: this.inboxCount,
      group_name: this.notification.data.group_name,
    });
  }

  get wrapLabel() {
    return false;
  }

  get description() {
    return null;
  }
}

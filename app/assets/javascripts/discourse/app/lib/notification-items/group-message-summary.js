import NotificationItemBase from "discourse/lib/notification-items/base";
import I18n from "I18n";

export default class extends NotificationItemBase {
  get label() {
    return I18n.t("notifications.group_message_summary", {
      count: this.notification.data.inbox_count,
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

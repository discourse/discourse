import NotificationTypeBase from "discourse/lib/notification-types/base";
import { userPath } from "discourse/lib/url";
import I18n from "I18n";

export default class extends NotificationTypeBase {
  get description() {
    return I18n.t("notifications.group_message_summary", {
      count: this.notification.data.inbox_count,
      group_name: this.notification.data.group_name,
    });
  }

  get label() {
    return null;
  }

  get linkHref() {
    return userPath(
      `${this.notification.data.username}/messages/group/${this.notification.data.group_name}`
    );
  }
}

import NotificationTypeBase from "discourse/lib/notification-types/base";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get description() {
    return i18n("notifications.group_message_summary", {
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

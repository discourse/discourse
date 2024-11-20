import NotificationTypeBase from "discourse/lib/notification-types/base";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get linkHref() {
    return userPath(
      `${this.notification.username || this.currentUser.username}/messages`
    );
  }

  get description() {
    return i18n("notifications.membership_request_consolidated", {
      group_name: this.notification.data.group_name,
      count: this.notification.data.count,
    });
  }

  get label() {
    return null;
  }
}

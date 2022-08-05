import NotificationItemBase from "discourse/lib/notification-items/base";
import { userPath } from "discourse/lib/url";
import I18n from "I18n";

export default class extends NotificationItemBase {
  get linkHref() {
    return userPath(
      `${this.notification.username || this.currentUser.username}/messages`
    );
  }

  get description() {
    return I18n.t("notifications.membership_request_consolidated", {
      group_name: this.notification.data.group_name,
      count: this.notification.data.count,
    });
  }

  get label() {
    return null;
  }
}

import NotificationTypeBase from "discourse/lib/notification-types/base";
import { userPath } from "discourse/lib/url";
import I18n from "I18n";

export default class extends NotificationTypeBase {
  get linkHref() {
    // TODO(osama): serialize username with notifications
    return userPath(
      `${this.currentUser.username}/notifications/likes-received?acting_username=${this.notification.data.username}`
    );
  }

  get description() {
    return I18n.t("notifications.liked_consolidated_description", {
      count: this.notification.data.count,
    });
  }
}

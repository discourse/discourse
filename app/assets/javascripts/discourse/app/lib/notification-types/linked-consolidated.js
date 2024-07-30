import NotificationTypeBase from "discourse/lib/notification-types/base";
import { userPath } from "discourse/lib/url";
import I18n from "discourse-i18n";

export default class extends NotificationTypeBase {
  get linkHref() {
    return userPath(
      `${this.currentUser.username}/notifications/links?acting_username=${this.notification.data.username}`
    );
  }

  get description() {
    return I18n.t("notifications.linked_consolidated_description", {
      count: this.notification.data.count,
    });
  }
}

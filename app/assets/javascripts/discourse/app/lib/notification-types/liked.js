import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get label() {
    const nameOrUsername = this.siteSettings.prioritize_full_name_in_ux
      ? this.notification.data.display_name ||
        this.notification.data.display_username
      : this.notification.data.display_username;

    if (this.count === 2) {
      const nameOrUsername2 = this.siteSettings.prioritize_full_name_in_ux
        ? this.notification.data.name2 || this.notification.data.username2
        : this.notification.data.username2;

      return i18n("notifications.liked_by_2_users", {
        username: nameOrUsername,
        username2: nameOrUsername2,
      });
    } else if (this.count > 2) {
      return i18n("notifications.liked_by_multiple_users", {
        username: nameOrUsername,
        count: this.count - 1,
      });
    } else {
      return super.label;
    }
  }

  get labelClasses() {
    if (this.count === 2) {
      return ["double-user"];
    } else if (this.count > 2) {
      return ["multi-user"];
    }
  }

  get count() {
    return this.notification.data.count;
  }
}

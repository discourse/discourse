import NotificationTypeBase from "discourse/lib/notification-types/base";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get label() {
    if (this.count === 2) {
      return i18n("notifications.liked_by_2_users", {
        username: this.username,
        username2: this.#username2,
      });
    } else if (this.count > 2) {
      return i18n("notifications.liked_by_multiple_users", {
        username: this.username,
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

  get #username2() {
    return formatUsername(this.notification.data.username2);
  }
}

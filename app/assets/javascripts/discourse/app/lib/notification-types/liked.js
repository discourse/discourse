import NotificationTypeBase from "discourse/lib/notification-types/base";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get label() {
    let name = "";
    let name2 = "";

    if (!this.siteSettings.prioritize_full_name_in_ux) {
      name = this.username;
      name2 = this.#username2;
    } else {
      name = this.notification.data.original_name;
      name2 = this.#full_name2;
    }

    if (this.count === 2) {
      return i18n("notifications.liked_by_2_users", {
        username: name,
        username2: name2,
      });
    } else if (this.count > 2) {
      return i18n("notifications.liked_by_multiple_users", {
        username: name,
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

  get #full_name2() {
    return this.notification.data.fullname2;
    // this doesn't exist on the returned object yet
  }
}

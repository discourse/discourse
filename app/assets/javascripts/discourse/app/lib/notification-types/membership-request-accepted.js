import NotificationTypeBase from "discourse/lib/notification-types/base";
import { groupPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get linkHref() {
    return groupPath(this.notification.data.group_name);
  }

  get description() {
    return i18n("notifications.membership_request_accepted", {
      group_name: this.notification.data.group_name,
    });
  }

  get label() {
    return null;
  }
}

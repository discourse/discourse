import NotificationItemBase from "discourse/lib/notification-items/base";
import { groupPath } from "discourse/lib/url";
import I18n from "I18n";

export default class extends NotificationItemBase {
  get linkHref() {
    return groupPath(this.notification.data.group_name);
  }

  get description() {
    return I18n.t("notifications.membership_request_accepted", {
      group_name: this.notification.data.group_name,
    });
  }

  get label() {
    return null;
  }
}

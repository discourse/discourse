import NotificationTypeBase from "discourse/lib/notification-types/base";
import { groupPath } from "discourse/lib/url";
import I18n from "I18n";

export default class extends NotificationTypeBase {
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

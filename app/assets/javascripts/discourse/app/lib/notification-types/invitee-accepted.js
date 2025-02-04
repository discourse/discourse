import NotificationTypeBase from "discourse/lib/notification-types/base";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get linkHref() {
    return userPath(this.notification.data.display_username);
  }

  get description() {
    return i18n("notifications.invitee_accepted_your_invitation");
  }
}

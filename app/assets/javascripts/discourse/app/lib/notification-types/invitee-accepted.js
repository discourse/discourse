import NotificationTypeBase from "discourse/lib/notification-types/base";
import { userPath } from "discourse/lib/url";
import I18n from "I18n";

export default class extends NotificationTypeBase {
  get linkHref() {
    return userPath(this.notification.data.display_username);
  }

  get description() {
    return I18n.t("notifications.invitee_accepted_your_invitation");
  }
}

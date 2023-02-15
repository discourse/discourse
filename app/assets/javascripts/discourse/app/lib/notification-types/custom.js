import NotificationTypeBase from "discourse/lib/notification-types/base";
import I18n from "I18n";

export default class extends NotificationTypeBase {
  get linkTitle() {
    if (this.notification.data.title) {
      return I18n.t(this.notification.data.title);
    }
  }

  get icon() {
    return `notification.${this.notification.data.message}`;
  }
}

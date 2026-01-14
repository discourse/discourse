import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get linkTitle() {
    if (this.notification.data.title) {
      return i18n(this.notification.data.title);
    }
  }

  get icon() {
    return `notification.${this.notification.data.message}`;
  }
}

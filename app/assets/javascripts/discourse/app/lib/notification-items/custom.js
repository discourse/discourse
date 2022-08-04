import NotificationItemBase from "discourse/lib/notification-items/base";
import I18n from "I18n";

export default class extends NotificationItemBase {
  get linkTitle() {
    if (this.notification.data.title) {
      return I18n.t(this.notification.data.title);
    }
    return super.linkTitle;
  }

  get icon() {
    return `notification.${this.notification.data.message}`;
  }
}

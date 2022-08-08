import NotificationItemBase from "discourse/lib/notification-items/base";
import I18n from "I18n";

export default class extends NotificationItemBase {
  get linkTitle() {
    if (this.notification.data.bookmark_name) {
      return I18n.t("notifications.titles.bookmark_reminder_with_name", {
        name: this.notification.data.bookmark_name,
      });
    }
    return super.linkTitle;
  }

  get description() {
    return super.description || this.notification.data.title;
  }
}

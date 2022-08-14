import NotificationItemBase from "discourse/lib/notification-items/base";
import I18n from "I18n";

export default class extends NotificationItemBase {
  get label() {
    return I18n.t("notifications.user_moved_post", { username: this.username });
  }
}

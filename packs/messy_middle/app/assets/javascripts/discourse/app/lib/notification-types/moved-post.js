import NotificationTypeBase from "discourse/lib/notification-types/base";
import I18n from "I18n";

export default class extends NotificationTypeBase {
  get label() {
    return I18n.t("notifications.user_moved_post", { username: this.username });
  }
}

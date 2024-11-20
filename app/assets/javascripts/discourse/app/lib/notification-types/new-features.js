import NotificationTypeBase from "discourse/lib/notification-types/base";
import getURL from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get label() {
    return null;
  }

  get description() {
    return i18n("notifications.new_features");
  }

  get linkHref() {
    return getURL("/admin/whats-new");
  }

  get icon() {
    return "gift";
  }
}

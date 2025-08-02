import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get label() {
    return null;
  }

  get description() {
    return i18n("notifications.admin_problems");
  }

  get linkHref() {
    return getURL("/admin");
  }

  get icon() {
    return "triangle-exclamation";
  }
}

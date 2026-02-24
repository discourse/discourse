import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get label() {
    return i18n("notifications.upcoming_changes.available.title");
  }

  get linkTitle() {
    return i18n("notifications.titles.upcoming_change_available", {
      changeName: this.notification.data.upcoming_change_humanized_name,
    });
  }

  get description() {
    return i18n("notifications.upcoming_changes.available.description", {
      changeName: this.notification.data.upcoming_change_humanized_name,
    });
  }

  get linkHref() {
    return getURL("/admin/config/upcoming-changes");
  }

  get icon() {
    return "flask";
  }
}

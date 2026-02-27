import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get label() {
    return i18n("notifications.upcoming_changes.available.title");
  }

  get linkTitle() {
    return i18n("notifications.titles.upcoming_change_available");
  }

  get description() {
    const data = this.notification.data;
    const names = data.upcoming_change_humanized_names || [
      data.upcoming_change_humanized_name,
    ];
    const count = data.count || names.length;

    if (count === 1) {
      return i18n("notifications.upcoming_changes.available.description", {
        changeName: names[0],
      });
    }

    if (count === 2) {
      return i18n("notifications.upcoming_changes.available.description_two", {
        changeName1: names[0],
        changeName2: names[1],
      });
    }

    return i18n("notifications.upcoming_changes.available.description_many", {
      changeName: names[0],
      otherChangeCount: count - 1,
    });
  }

  get linkHref() {
    const data = this.notification.data;
    const names = data.upcoming_change_names || [data.upcoming_change_name];

    return getURL(
      `/admin/config/upcoming-changes?changeNamesFilter=${names.join(",")}`
    );
  }

  get icon() {
    return "flask";
  }
}

import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get label() {
    return i18n("notifications.upcoming_changes.automatically_promoted.title");
  }

  get linkTitle() {
    return i18n("notifications.titles.upcoming_change_automatically_promoted");
  }

  get description() {
    const data = this.notification.data;
    const names = data.upcoming_change_humanized_names || [
      data.upcoming_change_humanized_name,
    ];
    const count = data.count || names.length;

    if (count === 1) {
      return i18n(
        "notifications.upcoming_changes.automatically_promoted.description",
        { changeName: names[0] }
      );
    }

    if (count === 2) {
      return i18n(
        "notifications.upcoming_changes.automatically_promoted.description_two",
        { changeName1: names[0], changeName2: names[1] }
      );
    }

    return i18n(
      "notifications.upcoming_changes.automatically_promoted.description_many",
      { changeName: names[0], otherChangeCount: count - 1 }
    );
  }

  get linkHref() {
    const data = this.notification.data;
    const names = data.upcoming_change_names || [data.upcoming_change_name];
    const permanentNames = this.site.permanent_upcoming_change_names || [];
    const nonPermanent = names.filter((n) => !permanentNames.includes(n));

    // Once a change is permanent it no longer shows on the upcoming changes
    // page, it's surfaced on the What's New page instead. If every change this
    // notification references is now permanent, send the admin there and scroll
    // to the relevant change. Otherwise keep the upcoming changes page, where
    // the still non-permanent changes are actionable.
    if (nonPermanent.length === 0 && names.length > 0) {
      return getURL(`/admin/whats-new?scrollTo=${names[0]}`);
    }

    return getURL(
      `/admin/config/upcoming-changes?changeNamesFilter=${names.join(",")}`
    );
  }

  get icon() {
    return "discourse-flask-check";
  }
}

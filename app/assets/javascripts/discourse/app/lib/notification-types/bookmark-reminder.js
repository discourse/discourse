import NotificationTypeBase from "discourse/lib/notification-types/base";
import getUrl from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default class extends NotificationTypeBase {
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

  get label() {
    return null;
  }

  get note() {
    return this.notification.data.bookmark_name;
  }

  get linkHref() {
    let linkHref = super.linkHref;
    if (linkHref) {
      return linkHref;
    }
    if (this.notification.data.bookmarkable_url) {
      return getUrl(this.notification.data.bookmarkable_url);
    }
  }
}

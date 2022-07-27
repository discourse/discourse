import UserMenuNotificationItem from "discourse/components/user-menu/notification-item";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";

export default class UserMenuGrantedBadgeNotificationItem extends UserMenuNotificationItem {
  get linkHref() {
    const badgeId = this.notification.data.badge_id;
    if (badgeId) {
      let slug = this.notification.data.badge_slug;
      if (!slug) {
        slug = this.notification.data.badge_name
          .replace(/[^A-Za-z0-9_]+/g, "-")
          .toLowerCase();
      }
      let username = this.notification.data.username;
      username = username ? `?username=${username.toLowerCase()}` : "";
      return getURL(`/badges/${badgeId}/${slug}${username}`);
    } else {
      return super.url;
    }
  }

  get label() {
    return I18n.t("notifications.granted_badge", {
      description: this.notification.data.badge_name,
    });
  }

  get wrapLabel() {
    return false;
  }

  get description() {
    return null;
  }
}

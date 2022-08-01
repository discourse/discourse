import UserMenuNotificationItem from "discourse/components/user-menu/notification-item";
import { userPath } from "discourse/lib/url";
import I18n from "I18n";

export default class UserMenuMembershipRequestConsolidatedNotificationItem extends UserMenuNotificationItem {
  get linkHref() {
    return userPath(
      `${this.notification.username || this.currentUser.username}/messages`
    );
  }

  get label() {
    return I18n.t("notifications.membership_request_consolidated", {
      group_name: this.notification.data.group_name,
      count: this.notification.data.count,
    });
  }

  get wrapLabel() {
    return false;
  }

  get description() {
    return null;
  }
}

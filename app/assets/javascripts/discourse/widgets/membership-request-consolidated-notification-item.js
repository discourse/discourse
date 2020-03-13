import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { userPath } from "discourse/lib/url";

createWidgetFrom(
  DefaultNotificationItem,
  "membership-request-consolidated-notification-item",
  {
    url() {
      return userPath(
        `${this.attrs.username || this.currentUser.username}/messages`
      );
    },

    text(notificationName, data) {
      return I18n.t("notifications.membership_request_consolidated", {
        group_name: data.group_name,
        count: parseInt(data.count, 10)
      });
    }
  }
);

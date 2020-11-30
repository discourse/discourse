import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import I18n from "I18n";
import { createWidgetFrom } from "discourse/widgets/widget";
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
        count: parseInt(data.count, 10),
      });
    },
  }
);

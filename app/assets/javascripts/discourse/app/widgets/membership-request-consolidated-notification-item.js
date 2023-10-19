import { userPath } from "discourse/lib/url";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { createWidgetFrom } from "discourse/widgets/widget";
import I18n from "discourse-i18n";

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

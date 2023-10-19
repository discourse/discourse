import { groupPath } from "discourse/lib/url";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { createWidgetFrom } from "discourse/widgets/widget";
import I18n from "discourse-i18n";

createWidgetFrom(
  DefaultNotificationItem,
  "membership-request-accepted-notification-item",
  {
    url(data) {
      return groupPath(data.group_name);
    },

    text(notificationName, data) {
      return I18n.t(`notifications.${notificationName}`, {
        group_name: data.group_name,
      });
    },
  }
);

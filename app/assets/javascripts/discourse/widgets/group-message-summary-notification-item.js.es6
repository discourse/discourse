import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";

createWidgetFrom(
  DefaultNotificationItem,
  "group-message-summary-notification-item",
  {
    text(notificationName, data) {
      const count = data.inbox_count;
      const group_name = data.group_name;

      return I18n.t("notifications.group_message_summary", {
        count,
        group_name
      });
    }
  }
);

import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { createWidgetFrom } from "discourse/widgets/widget";
import { userPath } from "discourse/lib/url";

createWidgetFrom(
  DefaultNotificationItem,
  "invitee-accepted-notification-item",
  {
    url(data) {
      return userPath(data.display_username);
    },
  }
);

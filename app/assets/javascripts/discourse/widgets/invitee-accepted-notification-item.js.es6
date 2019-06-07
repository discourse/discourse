import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { postUrl } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";

createWidgetFrom(DefaultNotificationItem, "invitee-accepted-notification-item", {
  url(data) {
    return userPath(data.display_username);
  },
});

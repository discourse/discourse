import { isEmpty } from "@ember/utils";
import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { escapeExpression } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";

createWidgetFrom(
  DefaultNotificationItem,
  "liked-consolidated-notification-item",
  {
    url(data) {
      return userPath(
        `${this.attrs.username ||
          this.currentUser
            .username}/notifications/likes-received?acting_username=${
          data.display_username
        }`
      );
    },

    description(data) {
      const description = I18n.t(
        "notifications.liked_consolidated_description",
        {
          count: parseInt(data.count, 10)
        }
      );

      return isEmpty(description) ? "" : escapeExpression(description);
    }
  }
);

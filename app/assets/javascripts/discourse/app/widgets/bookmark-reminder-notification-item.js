import { formatUsername } from "discourse/lib/utilities";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { createWidgetFrom } from "discourse/widgets/widget";
import I18n from "discourse-i18n";

createWidgetFrom(
  DefaultNotificationItem,
  "bookmark-reminder-notification-item",
  {
    text(notificationName, data) {
      const username = formatUsername(data.display_username);
      const description = this.description(data);

      return I18n.t("notifications.bookmark_reminder", {
        description,
        username,
      });
    },

    notificationTitle(notificationName, data) {
      if (notificationName) {
        if (data.bookmark_name) {
          return I18n.t(`notifications.titles.${notificationName}_with_name`, {
            name: data.bookmark_name,
          });
        } else {
          return I18n.t(`notifications.titles.${notificationName}`);
        }
      } else {
        return "";
      }
    },
  }
);

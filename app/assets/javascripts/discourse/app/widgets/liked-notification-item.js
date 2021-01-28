import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import I18n from "I18n";
import { createWidgetFrom } from "discourse/widgets/widget";
import { formatUsername } from "discourse/lib/utilities";

createWidgetFrom(DefaultNotificationItem, "liked-notification-item", {
  text(notificationName, data) {
    const username = formatUsername(data.display_username);
    const description = this.description(data);

    if (data.count > 1) {
      const count = data.count - 2;
      const username2 = formatUsername(data.username2);

      if (count === 0) {
        return I18n.t("notifications.liked_2", {
          description,
          username: `<span class="multi-username">${username}</span>`,
          username2: `<span class="multi-username">${username2}</span>`,
        });
      } else {
        return I18n.t("notifications.liked_many", {
          description,
          username: `<span class="multi-username">${username}</span>`,
          username2: `<span class="multi-username">${username2}</span>`,
          count,
        });
      }
    }

    return I18n.t("notifications.liked", { description, username });
  },
});

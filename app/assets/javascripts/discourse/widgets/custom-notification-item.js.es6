import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { formatUsername } from "discourse/lib/utilities";
import { iconNode } from "discourse-common/lib/icon-library";

createWidgetFrom(DefaultNotificationItem, "custom-notification-item", {
  notificationTitle(notificationName, data) {
    return data.title ? I18n.t(data.title) : "";
  },

  text(notificationName, data) {
    const username = formatUsername(data.display_username);
    const description = this.description(data);

    return I18n.t(data.message, { description, username });
  },

  icon(notificationName, data) {
    return iconNode(`notification.${data.message}`);
  }
});

import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { formatUsername } from "discourse/lib/utilities";
import { iconNode } from "discourse-common/lib/icon-library";

createWidgetFrom(DefaultNotificationItem, "custom-notification-item", {
  notificationTitle(notificationName, data) {
    if (data.customTitle) return I18n.t(data.customTitle);
    if (data.customTranslatedTitle) return data.customTranslatedTitle;

    return data.title ? I18n.t(data.title) : "";
  },

  url(data) {
    if (data.customUrl) return data.customUrl;

    return this._super(...arguments);
  },

  text(notificationName, data) {
    if (data.customMessage) return data.customMessage;

    const username = formatUsername(data.display_username);
    const description = this.description(data);
    return I18n.t(data.message, { description, username });
  },

  icon(notificationName, data) {
    return iconNode(
      data.customIcon ? data.customIcon : `notification.${data.message}`
    );
  }
});

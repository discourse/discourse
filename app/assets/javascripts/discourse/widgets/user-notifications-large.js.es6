import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { dateNode } from "discourse/helpers/node";

createWidget("large-notification-item", {
  buildClasses(attrs) {
    const result = ["item", "notification", "large-notification"];
    if (!attrs.get("read")) {
      result.push("unread");
    }
    return result;
  },

  html(attrs) {
    const notificationName = this.site.notificationLookup[
      attrs.notification_type
    ];

    return [
      this.attach(
        `${notificationName.dasherize()}-notification-item`,
        attrs,
        {},
        { fallbackWidgetName: "default-notification-item" }
      ),
      h("span.time", dateNode(attrs.created_at))
    ];
  }
});

export default createWidget("user-notifications-large", {
  html(attrs) {
    const notifications = attrs.notifications;
    const username = notifications.findArgs.username;

    return notifications.map(n => {
      n.username = username;
      return this.attach("large-notification-item", n);
    });
  }
});

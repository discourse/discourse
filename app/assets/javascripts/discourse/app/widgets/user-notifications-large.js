import { createWidget } from "discourse/widgets/widget";
import { dateNode } from "discourse/helpers/node";
import { h } from "virtual-dom";
import { dasherize } from "@ember/string";

createWidget("large-notification-item", {
  tagName: "li",

  buildClasses(attrs) {
    const result = ["item", "notification", "large-notification"];
    if (!attrs.get("read")) {
      result.push("unread");
    }
    return result;
  },

  html(attrs) {
    const notificationName =
      this.site.notificationLookup[attrs.notification_type];

    return [
      this.attach(
        `${dasherize(notificationName)}-notification-item`,
        attrs,
        {},
        {
          fallbackWidgetName: "default-notification-item",
          tagName: "div",
        }
      ),
      h("span.time", dateNode(attrs.created_at)),
    ];
  },
});

export default createWidget("user-notifications-large", {
  tagName: "ul.notifications.large-notifications",

  html(attrs) {
    const notifications = attrs.notifications;
    const username = notifications.findArgs.username;

    return notifications.map((n) => {
      n.username = username;
      return this.attach("large-notification-item", n);
    });
  },
});

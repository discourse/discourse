import NotificationOptionsComponent from "select-kit/components/notifications-button";
import { or } from "@ember/object/computed";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["category-notifications-button"],
  classNames: ["category-notifications-button"],
  isHidden: or("category.deleted"),

  selectKitOptions: {
    i18nPrefix: "category.notifications",
    showFullTitle: false,
  },
});
